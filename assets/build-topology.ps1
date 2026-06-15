#!/usr/bin/env pwsh
# build-topology.ps1 — Drive the draw.io MCP server to produce the Azure 101 Lab topology diagram.
# Mirrors what infra/main.bicep actually deploys:
#   - Subscription scope: tag policy audits, monthly budget, Activity Log -> LAW
#   - Shared RG:          Log Analytics workspace, user-assigned managed identity, DCR
#   - Lab RG:             2 peered VNets (with Bastion + workload subnets), 2 NSGs, 2 NICs,
#                         2 Ubuntu VMs, VM1 data disk, storage account, disk-usage alert
#   - NetworkWatcherRG:   VNet1 + VNet2 flow logs with Traffic Analytics
#
# Five real faults are annotated next to the resources they affect:
#   M1: CPU spike cron on VM1   M3: VM1 data disk filled >80%   M2: NSGs deny cross-VNet
#   M5: Storage missing tags    M6: Students lack Blob Data Contributor
#
# Requires: draw.io MCP server running at http://localhost:8080/mcp

$ErrorActionPreference = 'Stop'
$McpUrl = 'http://localhost:8080/mcp'
$script:CallId = 0
$script:SessionId = $null

function Invoke-Mcp {
    param([string]$Method, [hashtable]$Params = @{}, [switch]$IsNotification)
    $script:CallId++
    $bodyObj = @{ jsonrpc = '2.0'; method = $Method; params = $Params }
    if (-not $IsNotification) { $bodyObj['id'] = $script:CallId }
    $body = $bodyObj | ConvertTo-Json -Depth 30 -Compress
    $headers = @{ Accept = 'application/json, text/event-stream' }
    if ($script:SessionId) { $headers['Mcp-Session-Id'] = $script:SessionId }
    $resp = Invoke-WebRequest -Uri $McpUrl -Method POST -Body $body -ContentType 'application/json' -Headers $headers
    $sid = $resp.Headers['Mcp-Session-Id']
    if ($sid) { $script:SessionId = if ($sid -is [array]) { $sid[0] } else { $sid } }
    if ($IsNotification) { return }
    $dataLine = ($resp.Content -split "`n" | Where-Object { $_ -match '^data: ' } | Select-Object -First 1) -replace '^data: ', ''
    $parsed = $dataLine | ConvertFrom-Json -Depth 50
    if ($parsed.error) { throw "MCP error [$($parsed.error.code)]: $($parsed.error.message)" }
    return $parsed
}

function Invoke-McpTool {
    param([string]$ToolName, [hashtable]$Arguments)
    $resp = Invoke-Mcp -Method 'tools/call' -Params @{ name = $ToolName; arguments = $Arguments }
    $contentArr = $resp.result.content
    if (-not $contentArr -or $contentArr.Count -eq 0) { throw "Tool '$ToolName' returned no content" }
    $text = $contentArr[0].text
    if (-not $text) { throw "Tool '$ToolName' returned empty text. Type: $($contentArr[0].type)" }
    if ($text[0] -ne '{') {
        throw "Tool '$ToolName' returned non-JSON text: $($text.Substring(0, [Math]::Min(200, $text.Length)))"
    }
    return ($text | ConvertFrom-Json -Depth 50)
}

# --- Style strings reused throughout ---
$styleRg          = 'rounded=1;whiteSpace=wrap;dashed=1;dashPattern=10 6;fillColor=none;strokeColor=#8a8886;strokeWidth=2;arcSize=3;'
$styleVnet        = 'rounded=1;whiteSpace=wrap;fillColor=#f8fbff;strokeColor=#5c2d91;strokeWidth=2.5;arcSize=3;'
$styleSubnet      = 'rounded=1;whiteSpace=wrap;dashed=1;dashPattern=6 4;fillColor=#ffffff;strokeColor=#b3b0ad;strokeWidth=1.5;arcSize=3;'
$styleCard        = 'rounded=1;whiteSpace=wrap;fillColor=#ffffff;strokeColor=#d2d0ce;strokeWidth=1.25;fontSize=12;fontFamily=Segoe UI;align=center;verticalAlign=middle;'
$styleCardInfo    = 'rounded=1;whiteSpace=wrap;fillColor=#eff6fc;strokeColor=#0078d4;strokeWidth=1.25;fontSize=11;fontFamily=Segoe UI;align=center;verticalAlign=middle;'
$styleTitle       = 'text;fontSize=24;fontStyle=1;fontColor=#1f1f1f;align=center;verticalAlign=middle;fontFamily=Segoe UI;'
$styleSubtitle    = 'text;fontSize=13;fontColor=#605e5c;align=center;verticalAlign=middle;fontFamily=Segoe UI;'
$styleSection     = 'text;fontSize=16;fontStyle=1;fontColor=#005a9e;align=left;verticalAlign=middle;fontFamily=Segoe UI;'
$styleSectionVnet = 'text;fontSize=14;fontStyle=1;fontColor=#5c2d91;align=left;verticalAlign=middle;fontFamily=Segoe UI;'
$styleSectionSub  = 'text;fontSize=12;fontStyle=1;fontColor=#0b6a0b;align=left;verticalAlign=middle;fontFamily=Segoe UI;'
$styleTiny        = 'text;fontSize=10;fontColor=#605e5c;align=left;verticalAlign=middle;fontFamily=Segoe UI;'
$styleFault       = 'text;fontSize=10;fontColor=#d13438;fontStyle=2;align=left;verticalAlign=middle;fontFamily=Segoe UI;html=1;'
$styleEdge        = 'endArrow=classic;html=1;rounded=0;strokeColor=#0078d4;strokeWidth=1.6;fontSize=10;fontFamily=Segoe UI;fontColor=#323130;labelBackgroundColor=#ffffff;'
$styleEdgeSoft    = 'endArrow=classic;html=1;rounded=0;strokeColor=#7a7574;strokeWidth=1.4;dashed=1;fontSize=10;fontFamily=Segoe UI;fontColor=#605e5c;labelBackgroundColor=#ffffff;'
$styleEdgePeer    = 'endArrow=classic;startArrow=classic;html=1;rounded=0;strokeColor=#5c2d91;strokeWidth=2;fontSize=11;fontStyle=1;fontFamily=Segoe UI;fontColor=#5c2d91;labelBackgroundColor=#ffffff;'

Write-Host '=== Azure 101 Lab Topology Diagram Builder ===' -ForegroundColor Cyan

# --- Step 0: Initialize MCP session ---
Write-Host '[1/7] Initializing MCP session...'
$init = Invoke-Mcp -Method 'initialize' -Params @{
    protocolVersion = '2025-03-26'
    capabilities    = @{}
    clientInfo      = @{ name = 'topology-builder'; version = '2.0' }
}
Write-Host "  Server: $($init.result.serverInfo.name) v$($init.result.serverInfo.version)"
Write-Host "  Session: $($script:SessionId)"
Invoke-Mcp -Method 'notifications/initialized' -IsNotification

# --- Step 1: Look up Azure shape names ---
Write-Host '[2/7] Searching for shapes...'
$shapeQueries = @(
    'Virtual Machine','Network Security Groups','Storage Accounts','Log Analytics Workspaces',
    'Virtual Networks','Network Interfaces','Data Collection Rules','Managed Identities',
    'Bastions','Public IP','Disks','Policy','Cost Budgets','Subscriptions','Activity Log',
    'Network Watcher','Alerts','Blob','Container Instances'
)
$shapesResp = Invoke-McpTool -ToolName 'search-shapes' -Arguments @{ queries = $shapeQueries }
$shapeMap = @{}
foreach ($r in $shapesResp.data.results) {
    if ($r.matches -and $r.matches.Count -gt 0) {
        $shapeMap[$r.query] = $r.matches[0].name
    }
}
function Get-Shape { param([string]$Key, [string]$Fallback)
    if ($shapeMap[$Key]) { return $shapeMap[$Key] } else { return $Fallback }
}
$shapeVm     = Get-Shape 'Virtual Machine'         'Virtual Machine'
$shapeNsg    = Get-Shape 'Network Security Groups' 'Network Security Groups'
$shapeStor   = Get-Shape 'Storage Accounts'        'Storage Accounts'
$shapeLaw    = Get-Shape 'Log Analytics Workspaces' 'Log Analytics Workspaces'
$shapeNic    = Get-Shape 'Network Interfaces'      'Network Interfaces'
$shapeDcr    = Get-Shape 'Data Collection Rules'   'Data Collection Rules'
$shapeMi     = Get-Shape 'Managed Identities'      'Managed Identities'
$shapeBast   = Get-Shape 'Bastions'                'Bastions'
$shapePip    = Get-Shape 'Public IP'               'Public IP Addresses'
$shapeDisk   = Get-Shape 'Disks'                   'Disks'
$shapePolicy = Get-Shape 'Policy'                  'Policy'
$shapeBudget = Get-Shape 'Cost Budgets'            'Cost Budgets'
$shapeSub    = Get-Shape 'Subscriptions'           'Subscriptions'
$shapeAct    = Get-Shape 'Activity Log'            'Activity Log'
$shapeNw     = Get-Shape 'Network Watcher'         'Network Watcher'
$shapeAlert  = Get-Shape 'Alerts'                  'Alerts'
$shapeBlob   = Get-Shape 'Blob'                    'Blob Block'
foreach ($q in $shapeQueries) {
    $name = if ($shapeMap[$q]) { $shapeMap[$q] } else { 'NONE' }
    Write-Host ("  {0,-28} -> {1}" -f $q, $name)
}

# --- Step 2: Create container groups (in z-order: outer RGs first) ---
Write-Host '[3/7] Creating groups...'
$groupsResp = Invoke-McpTool -ToolName 'create-groups' -Arguments @{
    transactional = $true
    groups = @(
        # Subscription banner (full width)
        @{ text=''; x=40;   y=95;  width=1320; height=120; temp_id='sub-rg'; style=$styleRg }
        # Shared RG (left column, upper)
        @{ text=''; x=40;   y=240; width=320;  height=300; temp_id='shared-rg'; style=$styleRg }
        # NetworkWatcherRG (left column, lower)
        @{ text=''; x=40;   y=560; width=320;  height=240; temp_id='nw-rg'; style=$styleRg }
        # Lab RG (large right panel)
        @{ text=''; x=380;  y=240; width=980;  height=820; temp_id='lab-rg'; style=$styleRg }
        # VNet1
        @{ text=''; x=400;  y=295; width=460;  height=440; temp_id='vnet1'; style=$styleVnet }
        # VNet2
        @{ text=''; x=880;  y=295; width=460;  height=440; temp_id='vnet2'; style=$styleVnet }
        # AzureBastionSubnet inside VNet1
        @{ text=''; x=415;  y=355; width=430;  height=110; temp_id='bastion-subnet'; style=$styleSubnet }
        # workload-snet1 inside VNet1
        @{ text=''; x=415;  y=480; width=430;  height=245; temp_id='workload-snet1'; style=$styleSubnet }
        # workload-snet2 inside VNet2
        @{ text=''; x=895;  y=355; width=430;  height=370; temp_id='workload-snet2'; style=$styleSubnet }
    )
}
$groupIds = @{}
foreach ($g in $groupsResp.data.results) {
    $groupIds[$g.temp_id] = $g.cell.id
    Write-Host "  Group: $($g.temp_id) -> $($g.cell.id)"
}
$xml = $groupsResp.data.diagram_xml

# --- Step 3: Add all vertex + edge cells ---
Write-Host '[4/7] Adding cells (vertices + edges)...'
$cells = [System.Collections.ArrayList]@()

function Add-Vertex { param($x,$y,$w=120,$h=60,$text='',$style=$null,$shape=$null,$tempId=$null)
    $v = @{ type='vertex'; x=$x; y=$y; text=$text }
    if ($w) { $v.width = $w }
    if ($h) { $v.height = $h }
    if ($style) { $v.style = $style }
    if ($shape) { $v.shape_name = $shape }
    if ($tempId) { $v.temp_id = $tempId }
    [void]$cells.Add($v)
}
function Add-Edge { param($src,$tgt,$text='',$style=$null,$tempId=$null)
    $e = @{ type='edge'; source_id=$src; target_id=$tgt; text=$text }
    if ($style) { $e.style = $style }
    if ($tempId) { $e.temp_id = $tempId }
    [void]$cells.Add($e)
}

# --- Title + subtitle ---
Add-Vertex -x 360 -y 15  -w 700 -h 36 -text 'Azure 101 Lab — Per-group Topology' -style $styleTitle
Add-Vertex -x 300 -y 55  -w 820 -h 22 -text 'Two peered VNets · Two Ubuntu VMs · Shared Log Analytics · Five baked-in faults across Modules 1–7' -style $styleSubtitle

# --- Subscription scope banner labels + tiles ---
Add-Vertex -x 60   -y 105 -w 260 -h 22 -text 'Subscription scope'             -style $styleSection
Add-Vertex -x 60   -y 125 -w 260 -h 16 -text 'Deployed once per group subscription' -style $styleTiny

# Subscription icon (anchor)
Add-Vertex -x 70   -y 155 -w 60 -h 50 -text 'Subscription' -shape $shapeSub -tempId 'sub-icon'

# Three subscription-scope tiles
Add-Vertex -x 200  -y 145 -w 320 -h 70 -text "Tag Policy Audits`n(Department + Environment)" -shape $shapePolicy -tempId 'tile-policy'
Add-Vertex -x 220  -y 195 -w 280 -h 16 -text 'FAULT (M5): resources missing required tags' -style $styleFault

Add-Vertex -x 540  -y 145 -w 320 -h 70 -text "Monthly Cost Budget`n`$50 / month · email alerts" -shape $shapeBudget -tempId 'tile-budget'

Add-Vertex -x 880  -y 145 -w 320 -h 70 -text "Activity Log → LAW`n(diagnostic setting, allLogs)" -shape $shapeAct -tempId 'tile-activity'

# --- Shared RG labels + tiles ---
Add-Vertex -x 60   -y 250 -w 260 -h 22 -text 'Shared Resource Group'          -style $styleSection
Add-Vertex -x 60   -y 270 -w 260 -h 16 -text '{labName}-shared-rg'            -style $styleTiny

Add-Vertex -x 60   -y 296 -w 280 -h 64 -text 'Log Analytics Workspace' -shape $shapeLaw -tempId 'law'
Add-Vertex -x 60   -y 372 -w 280 -h 64 -text 'Data Collection Rule (Perf + Syslog)' -shape $shapeDcr -tempId 'dcr'
Add-Vertex -x 60   -y 448 -w 280 -h 64 -text 'User-Assigned Managed Identity (script identity)' -shape $shapeMi -tempId 'mi'

# --- NetworkWatcherRG labels + tiles ---
Add-Vertex -x 60   -y 570 -w 260 -h 22 -text 'NetworkWatcherRG'               -style $styleSection
Add-Vertex -x 60   -y 590 -w 260 -h 16 -text 'Existing regional NW resource'  -style $styleTiny

Add-Vertex -x 60   -y 616 -w 280 -h 50 -text 'Network Watcher (regional)' -shape $shapeNw -tempId 'nw'
Add-Vertex -x 60   -y 676 -w 280 -h 44 -text 'VNet1 Flow Log + Traffic Analytics' -style $styleCardInfo -tempId 'flow1'
Add-Vertex -x 60   -y 730 -w 280 -h 44 -text 'VNet2 Flow Log + Traffic Analytics' -style $styleCardInfo -tempId 'flow2'

# --- Lab RG labels ---
Add-Vertex -x 400  -y 250 -w 400 -h 22 -text 'Lab Resource Group'             -style $styleSection
Add-Vertex -x 400  -y 270 -w 400 -h 16 -text '{labName}-rg — shared by all students in the group' -style $styleTiny

# --- VNet1 ---
Add-Vertex -x 415  -y 303 -w 380 -h 22 -text 'VNet1 — 10.10.0.0/16' -style $styleSectionVnet
Add-Vertex -x 425  -y 363 -w 250 -h 18 -text 'AzureBastionSubnet — 10.10.254.0/26' -style $styleSectionSub
Add-Vertex -x 425  -y 488 -w 250 -h 18 -text 'workload-snet1 — 10.10.1.0/24'       -style $styleSectionSub

# Bastion + PIP inside AzureBastionSubnet
Add-Vertex -x 440  -y 390 -w 180 -h 60 -text 'Azure Bastion' -shape $shapeBast -tempId 'bastion'
Add-Vertex -x 690  -y 390 -w 140 -h 60 -text 'Bastion Public IP' -shape $shapePip -tempId 'bastion-pip'

# NSG1 in workload-snet1 (top)
Add-Vertex -x 660  -y 510 -w 175 -h 60 -text 'NSG1' -shape $shapeNsg -tempId 'nsg1'
Add-Vertex -x 660  -y 575 -w 175 -h 26 -text 'FAULT (M2): denies<br>outbound to VNet2' -style $styleFault

# NIC1 + VM1 + Data disk inside workload-snet1
Add-Vertex -x 435  -y 510 -w 170 -h 50 -text 'NIC1 (no public IP)' -shape $shapeNic -tempId 'nic1'
Add-Vertex -x 435  -y 575 -w 170 -h 70 -text "VM1 (Ubuntu 22.04)`nStandard_D2alds_v7`n+ AMA · UAI · DCR" -shape $shapeVm -tempId 'vm1'
Add-Vertex -x 620  -y 615 -w 165 -h 60 -text "Data Disk 4 GB`n/mnt/data" -shape $shapeDisk -tempId 'datadisk'
Add-Vertex -x 435  -y 650 -w 350 -h 16 -text 'FAULT (M1): CPU spike cron every 15 min  ·  FAULT (M3): data disk filled &gt;80%' -style $styleFault

# --- VNet2 ---
Add-Vertex -x 895  -y 303 -w 380 -h 22 -text 'VNet2 — 10.11.0.0/16' -style $styleSectionVnet
Add-Vertex -x 905  -y 363 -w 250 -h 18 -text 'workload-snet2 — 10.11.1.0/24' -style $styleSectionSub

# NSG2 in workload-snet2 (top)
Add-Vertex -x 1140 -y 395 -w 170 -h 60 -text 'NSG2' -shape $shapeNsg -tempId 'nsg2'
Add-Vertex -x 1140 -y 460 -w 175 -h 26 -text 'FAULT (M2): denies<br>inbound from VNet1' -style $styleFault

# NIC2 + VM2 inside workload-snet2
Add-Vertex -x 920  -y 395 -w 170 -h 50 -text 'NIC2 (no public IP)' -shape $shapeNic -tempId 'nic2'
Add-Vertex -x 920  -y 460 -w 170 -h 70 -text "VM2 (Ubuntu 22.04)`nStandard_D2alds_v7`n+ AMA · DCR" -shape $shapeVm -tempId 'vm2'
Add-Vertex -x 1110 -y 500 -w 200 -h 60 -text "ncat -lk 1433`nsql-listener.service" -style $styleCard -tempId 'sql-listener'
Add-Vertex -x 920  -y 600 -w 390 -h 100 -text "Module 2 target: students must add allow rules on BOTH NSGs for TCP 1433 from peer VNet to reach this listener." -style $styleCardInfo

# --- Lab RG bottom row: storage + disk alert ---
Add-Vertex -x 400  -y 760 -w 360 -h 110 -text "Storage Account`n(boot diagnostics · blob diag → LAW)" -shape $shapeStor -tempId 'storage'
Add-Vertex -x 595  -y 790 -w 160 -h 26 -text 'lab-data container' -shape $shapeBlob -tempId 'lab-data'
Add-Vertex -x 400  -y 870 -w 380 -h 16 -text 'FAULT (M5): missing Department / Environment tags' -style $styleFault
Add-Vertex -x 400  -y 888 -w 380 -h 16 -text 'FAULT (M6): no Storage Blob Data Contributor for students' -style $styleFault

Add-Vertex -x 800  -y 760 -w 280 -h 100 -text "Disk-Usage Alert`n(Scheduled Query Rule)`nVM1 /mnt/data > 80% → Action Group" -shape $shapeAlert -tempId 'alert'

Add-Vertex -x 1100 -y 760 -w 240 -h 140 -text "Student RBAC (optional)`n`n• Contributor on Lab RG`n• Scoped RBAC Admin on Storage`n  (ABAC: only Blob Data roles)" -style $styleCardInfo -tempId 'student-rbac'

# --- Module legend (bottom of canvas, inside lab RG) ---
Add-Vertex -x 400  -y 945 -w 940 -h 100 -text "<b>Fault → Module map</b><br>M1 VM Performance · M2 Network Connectivity · M3 Disk Capacity · M4 Azure Monitor &amp; KQL<br>M5 Cost &amp; Policy · M6 RBAC Data Plane · M7 Storage Access Audit · M8 Change Tracking" -style 'rounded=1;whiteSpace=wrap;fillColor=#fff4ce;strokeColor=#d8b85b;strokeWidth=1;fontSize=11;fontFamily=Segoe UI;align=left;verticalAlign=middle;html=1;'

# --- Edges (resource relationships) ---
# Activity Log -> LAW
Add-Edge 'tile-activity' 'law' 'diagnostic setting' $styleEdge
# DCR -> LAW
Add-Edge 'dcr' 'law' 'data flow' $styleEdge
# VM1 -> DCR (AMA + association)
Add-Edge 'vm1' 'dcr' 'AMA + DCR assoc' $styleEdgeSoft
# VM2 -> DCR
Add-Edge 'vm2' 'dcr' 'AMA + DCR assoc' $styleEdgeSoft
# VM1 -> Storage (boot diag + blob upload via MI)
Add-Edge 'vm1' 'storage' 'boot diag + blob upload' $styleEdgeSoft
# VM2 -> Storage (boot diag)
Add-Edge 'vm2' 'storage' 'boot diag' $styleEdgeSoft
# Storage -> LAW (blob diag)
Add-Edge 'storage' 'law' 'blob diag (StorageBlobLogs)' $styleEdge
# Disk alert -> LAW
Add-Edge 'alert' 'law' 'KQL on Perf' $styleEdge
# VNet1 <-> VNet2 peering (between VNet groups)
Add-Edge $groupIds['vnet1'] $groupIds['vnet2'] 'VNet Peering (NSGs block 1433)' $styleEdgePeer
# Bastion -> VMs
Add-Edge 'bastion' 'vm1' 'SSH' $styleEdgeSoft
Add-Edge 'bastion' 'vm2' 'SSH (over peering)' $styleEdgeSoft
# Managed Identity -> Storage (Blob Data Contributor)
Add-Edge 'mi' 'storage' 'Blob Data Contributor' $styleEdge
# Managed Identity -> Lab RG (Contributor)
Add-Edge 'mi' $groupIds['lab-rg'] 'Contributor (RG)' $styleEdge
# Flow logs -> VNets (target), Storage (logs), LAW (analytics)
Add-Edge 'flow1' $groupIds['vnet1'] 'captures' $styleEdgeSoft
Add-Edge 'flow2' $groupIds['vnet2'] 'captures' $styleEdgeSoft
Add-Edge 'flow1' 'storage' 'logs' $styleEdgeSoft
Add-Edge 'flow2' 'storage' 'logs' $styleEdgeSoft
Add-Edge 'flow1' 'law' 'Traffic Analytics' $styleEdge

$cellsResp = Invoke-McpTool -ToolName 'add-cells' -Arguments @{
    transactional = $true
    diagram_xml   = $xml
    cells         = @($cells)
}
$cellIds = @{}
foreach ($c in $cellsResp.data.results) {
    if ($c.temp_id) {
        $cid = if ($c.cell) { $c.cell.id } else { $c.id }
        $cellIds[$c.temp_id] = $cid
    }
}
$xml = $cellsResp.data.diagram_xml
Write-Host "  Added $($cellsResp.data.results.Count) cells."

# --- Step 4: Nest groups inside their parents ---
Write-Host '[5/7] Assigning cells to groups...'
$assignResult = Invoke-McpTool -ToolName 'add-cells-to-group' -Arguments @{
    transactional = $true
    diagram_xml   = $xml
    assignments   = @(
        # VNets inside Lab RG
        @{ cell_id = $groupIds['vnet1']; group_id = $groupIds['lab-rg'] }
        @{ cell_id = $groupIds['vnet2']; group_id = $groupIds['lab-rg'] }
        # Subnets inside their VNets
        @{ cell_id = $groupIds['bastion-subnet'];  group_id = $groupIds['vnet1'] }
        @{ cell_id = $groupIds['workload-snet1']; group_id = $groupIds['vnet1'] }
        @{ cell_id = $groupIds['workload-snet2']; group_id = $groupIds['vnet2'] }
    )
}
$xml = $assignResult.data.diagram_xml
Write-Host '  Groups nested successfully.'

# --- Step 5: Finish (resolve shape placeholders) ---
Write-Host '[6/7] Finishing diagram (resolving placeholders)...'
$finished = Invoke-McpTool -ToolName 'finish-diagram' -Arguments @{
    diagram_xml = $xml
    compress    = $false
}
$xml = $finished.data.xml
if (-not $xml) { $xml = $finished.data.diagram_xml }
Write-Host '  Placeholders resolved.'

# --- Step 6: Export final compressed XML ---
Write-Host '[7/7] Exporting diagram...'
$exported = Invoke-McpTool -ToolName 'export-diagram' -Arguments @{
    diagram_xml = $xml
    compress    = $true
}
$finalXml = $exported.data.xml
Write-Host "  Compressed: $($exported.data.compression.enabled)"

# --- Save ---
$outPath = Join-Path $PSScriptRoot 'azure-101-lab-topology.drawio'
$finalXml | Set-Content $outPath -Encoding UTF8 -NoNewline
Write-Host "`nSaved to: $outPath" -ForegroundColor Green
Write-Host '=== Done ===' -ForegroundColor Cyan
