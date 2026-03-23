#!/usr/bin/env pwsh
# build-topology.ps1 — Drive the draw.io MCP server to create the Azure 101 Lab topology diagram
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
    $body = $bodyObj | ConvertTo-Json -Depth 20 -Compress
    $headers = @{ Accept = 'application/json, text/event-stream' }
    if ($script:SessionId) { $headers['Mcp-Session-Id'] = $script:SessionId }
    $resp = Invoke-WebRequest -Uri $McpUrl -Method POST -Body $body -ContentType 'application/json' -Headers $headers
    $sid = $resp.Headers['Mcp-Session-Id']
    if ($sid) {
        $script:SessionId = if ($sid -is [array]) { $sid[0] } else { $sid }
    }
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
    if (-not $contentArr -or $contentArr.Count -eq 0) {
        throw "Tool '$ToolName' returned no content"
    }
    $text = $contentArr[0].text
    if (-not $text) {
        throw "Tool '$ToolName' returned empty text. Type: $($contentArr[0].type)"
    }
    if ($text[0] -ne '{') {
        throw "Tool '$ToolName' returned non-JSON text: $($text.Substring(0, [Math]::Min(200, $text.Length)))"
    }
    return ($text | ConvertFrom-Json -Depth 50)
}

Write-Host '=== Azure 101 Lab Topology Diagram Builder ===' -ForegroundColor Cyan

# --- Step 0: Initialize ---
Write-Host '[1/7] Initializing MCP session...'
$init = Invoke-Mcp -Method 'initialize' -Params @{
    protocolVersion = '2025-03-26'
    capabilities    = @{}
    clientInfo      = @{ name = 'topology-builder'; version = '1.0' }
}
Write-Host "  Server: $($init.result.serverInfo.name) v$($init.result.serverInfo.version)"
Write-Host "  Session: $($script:SessionId)"

Invoke-Mcp -Method 'notifications/initialized' -IsNotification

# --- Step 1: Search shapes ---
Write-Host '[2/7] Searching for shapes...'
$shapesResp = Invoke-McpTool -ToolName 'search-shapes' -Arguments @{
    queries = @(
        'Virtual Machine'
        'Network Security Groups'
        'Route Tables'
        'Storage Accounts'
        'Log Analytics Workspaces'
        'Virtual Networks'
        'Subnets'
        'Network Interfaces'
        'Data Collection Rules'
        'Managed Identities'
    )
}

$shapeMap = @{}
foreach ($r in $shapesResp.data.results) {
    if ($r.matches -and $r.matches.Count -gt 0) {
        $shapeMap[$r.query] = $r.matches[0].name
        Write-Host "  $($r.query) -> $($r.matches[0].name)"
    }
    else {
        Write-Host "  $($r.query) -> NO MATCH" -ForegroundColor Yellow
    }
}

# --- Step 2: Create groups (transactional) ---
Write-Host '[3/7] Creating groups...'
$groupsResp = Invoke-McpTool -ToolName 'create-groups' -Arguments @{
    transactional = $true
    groups        = @(
        @{ text = ''; x = 40; y = 110; width = 770; height = 510; temp_id = 'student-rg'
           style = 'rounded=1;whiteSpace=wrap;dashed=1;dashPattern=10 6;fillColor=none;strokeColor=#8a8886;strokeWidth=2;arcSize=3;' }
        @{ text = ''; x = 40; y = 670; width = 770; height = 170; temp_id = 'shared-rg'
           style = 'rounded=1;whiteSpace=wrap;dashed=1;dashPattern=10 6;fillColor=none;strokeColor=#8a8886;strokeWidth=2;arcSize=3;' }
        @{ text = ''; x = 60; y = 200; width = 420; height = 390; temp_id = 'vnet'
           style = 'rounded=1;whiteSpace=wrap;fillColor=#f8fbff;strokeColor=#0078d4;strokeWidth=2;arcSize=3;' }
        @{ text = ''; x = 80; y = 275; width = 180; height = 160; temp_id = 'mgmt-subnet'
           style = 'rounded=1;whiteSpace=wrap;dashed=1;dashPattern=6 4;fillColor=#ffffff;strokeColor=#b3b0ad;strokeWidth=1.5;arcSize=3;' }
        @{ text = ''; x = 280; y = 275; width = 180; height = 280; temp_id = 'workload-subnet'
           style = 'rounded=1;whiteSpace=wrap;dashed=1;dashPattern=6 4;fillColor=#ffffff;strokeColor=#b3b0ad;strokeWidth=1.5;arcSize=3;' }
    )
}

$groupIds = @{}
$grpData = $groupsResp.data
foreach ($g in $grpData.results) {
    $groupIds[$g.temp_id] = $g.cell.id
    Write-Host "  Group: $($g.temp_id) -> $($g.cell.id)"
}
$xml = $grpData.diagram_xml

# --- Step 3: Add all cells ---
Write-Host '[4/7] Adding cells (vertices + edges)...'

$vmShape = if ($shapeMap['Virtual Machine']) { $shapeMap['Virtual Machine'] } else { 'Virtual Machine' }
$nsgShape = if ($shapeMap['Network Security Groups']) { $shapeMap['Network Security Groups'] } else { 'Network Security Groups' }
$rtShape = if ($shapeMap['Route Tables']) { $shapeMap['Route Tables'] } else { 'Route Tables' }
$saShape = if ($shapeMap['Storage Accounts']) { $shapeMap['Storage Accounts'] } else { 'Storage Accounts' }
$lawShape = if ($shapeMap['Log Analytics Workspaces']) { $shapeMap['Log Analytics Workspaces'] } else { 'Log Analytics Workspaces' }
$nicShape = if ($shapeMap['Network Interfaces']) { $shapeMap['Network Interfaces'] } else { 'Network Interfaces' }
$dcrShape = $shapeMap['Data Collection Rules']
$miShape = $shapeMap['Managed Identities']

$cellsDef = [System.Collections.ArrayList]@()

# Title + subtitle
[void]$cellsDef.Add(@{ type = 'vertex'; x = 200; y = 20; width = 450; height = 40
    text = 'Azure 101 Lab v2 Topology'
    style = 'text;fontSize=24;fontStyle=1;fontColor=#1f1f1f;align=center;verticalAlign=middle;fontFamily=Segoe UI;' })
[void]$cellsDef.Add(@{ type = 'vertex'; x = 150; y = 60; width = 550; height = 25
    text = 'Per-learner sandbox with baked-in troubleshooting faults'
    style = 'text;fontSize=13;fontColor=#605e5c;align=center;verticalAlign=middle;fontFamily=Segoe UI;' })

# Group labels
[void]$cellsDef.Add(@{ type = 'vertex'; x = 65; y = 115; width = 300; height = 28
    text = 'Student Resource Group'
    style = 'text;fontSize=18;fontStyle=1;fontColor=#005a9e;align=left;verticalAlign=middle;fontFamily=Segoe UI;' })
[void]$cellsDef.Add(@{ type = 'vertex'; x = 65; y = 675; width = 300; height = 28
    text = 'Shared Resource Group'
    style = 'text;fontSize=18;fontStyle=1;fontColor=#005a9e;align=left;verticalAlign=middle;fontFamily=Segoe UI;' })
[void]$cellsDef.Add(@{ type = 'vertex'; x = 80; y = 208; width = 200; height = 24
    text = 'Virtual Network'
    style = 'text;fontSize=16;fontStyle=1;fontColor=#4b3fa8;align=left;verticalAlign=middle;fontFamily=Segoe UI;' })
[void]$cellsDef.Add(@{ type = 'vertex'; x = 92; y = 282; width = 160; height = 22
    text = 'Management Subnet'
    style = 'text;fontSize=14;fontStyle=1;fontColor=#2b579a;align=left;verticalAlign=middle;fontFamily=Segoe UI;' })
[void]$cellsDef.Add(@{ type = 'vertex'; x = 292; y = 282; width = 160; height = 22
    text = 'Workload Subnet'
    style = 'text;fontSize=14;fontStyle=1;fontColor=#0b6a0b;align=left;verticalAlign=middle;fontFamily=Segoe UI;' })

# Mgmt subnet text
[void]$cellsDef.Add(@{ type = 'vertex'; x = 100; y = 325; width = 145; height = 70
    text = 'Reserved for management and validation exercises'
    style = 'text;fontSize=12;fontColor=#605e5c;align=center;verticalAlign=middle;whiteSpace=wrap;fontFamily=Segoe UI;' })

# Shaped vertices
[void]$cellsDef.Add(@{ type = 'vertex'; shape_name = $vmShape; x = 346; y = 330; text = 'Ubuntu VM'; temp_id = 'vm' })
[void]$cellsDef.Add(@{ type = 'vertex'; shape_name = $nicShape; x = 346; y = 440; text = 'NIC (no public IP)'; temp_id = 'nic' })
[void]$cellsDef.Add(@{ type = 'vertex'; shape_name = $nsgShape; x = 560; y = 230; text = 'NSG'; temp_id = 'nsg' })
[void]$cellsDef.Add(@{ type = 'vertex'; shape_name = $rtShape; x = 560; y = 360; text = 'Route Table'; temp_id = 'rt' })
[void]$cellsDef.Add(@{ type = 'vertex'; shape_name = $saShape; x = 560; y = 490; text = 'Storage Account'; temp_id = 'sa' })
[void]$cellsDef.Add(@{ type = 'vertex'; shape_name = $lawShape; x = 100; y = 720; text = 'Log Analytics Workspace'; temp_id = 'law' })

# DCR
if ($dcrShape) {
    [void]$cellsDef.Add(@{ type = 'vertex'; shape_name = $dcrShape; x = 350; y = 720; text = 'Data Collection Rule'; temp_id = 'dcr' })
} else {
    [void]$cellsDef.Add(@{ type = 'vertex'; x = 330; y = 720; width = 100; height = 48
        text = 'Data Collection Rule'; temp_id = 'dcr'
        style = 'rounded=1;whiteSpace=wrap;fillColor=#E6F2FA;strokeColor=#0078D4;fontSize=11;fontFamily=Segoe UI;' })
}

# Managed Identity
if ($miShape) {
    [void]$cellsDef.Add(@{ type = 'vertex'; shape_name = $miShape; x = 600; y = 720; text = 'Managed Identity'; temp_id = 'mi' })
} else {
    [void]$cellsDef.Add(@{ type = 'vertex'; x = 580; y = 720; width = 100; height = 48
        text = 'Managed Identity'; temp_id = 'mi'
        style = 'rounded=1;whiteSpace=wrap;fillColor=#E6F2FA;strokeColor=#0078D4;fontSize=11;fontFamily=Segoe UI;' })
}

# Fault annotations
[void]$cellsDef.Add(@{ type = 'vertex'; x = 618; y = 262; width = 170; height = 18
    text = 'FAULT: DenyAllInbound at priority 200'
    style = 'text;fontSize=10;fontColor=#d13438;align=left;verticalAlign=middle;fontFamily=Segoe UI;fontStyle=2;' })
[void]$cellsDef.Add(@{ type = 'vertex'; x = 618; y = 392; width = 170; height = 18
    text = 'FAULT: Blackhole route 0.0.0.0/0'
    style = 'text;fontSize=10;fontColor=#d13438;align=left;verticalAlign=middle;fontFamily=Segoe UI;fontStyle=2;' })
[void]$cellsDef.Add(@{ type = 'vertex'; x = 298; y = 375; width = 160; height = 18
    text = 'FAULT: VM deallocated'
    style = 'text;fontSize=10;fontColor=#d13438;align=left;verticalAlign=middle;fontFamily=Segoe UI;fontStyle=2;' })

# Edges (after all vertices)
[void]$cellsDef.Add(@{ type = 'edge'; source_id = 'nsg'; target_id = $groupIds['workload-subnet']; text = 'associated' })
[void]$cellsDef.Add(@{ type = 'edge'; source_id = 'rt'; target_id = $groupIds['workload-subnet']; text = 'associated' })
[void]$cellsDef.Add(@{ type = 'edge'; source_id = 'vm'; target_id = 'nic' })
[void]$cellsDef.Add(@{ type = 'edge'; source_id = 'vm'; target_id = 'sa'; text = 'boot diagnostics' })
[void]$cellsDef.Add(@{ type = 'edge'; source_id = 'vm'; target_id = 'dcr'; text = 'AMA agent' })
[void]$cellsDef.Add(@{ type = 'edge'; source_id = 'dcr'; target_id = 'law'; text = 'data flow' })

$cellsResp = Invoke-McpTool -ToolName 'add-cells' -Arguments @{
    transactional = $true
    diagram_xml   = $xml
    cells         = @($cellsDef)
}

$cellIds = @{}
foreach ($c in $cellsResp.data.results) {
    if ($c.temp_id) {
        $cId = if ($c.cell) { $c.cell.id } else { $c.id }
        $cellIds[$c.temp_id] = $cId
        Write-Host "  Cell: $($c.temp_id) -> $cId"
    }
}
$xml = $cellsResp.data.diagram_xml

# --- Step 4: Assign cells to groups ---
Write-Host '[5/7] Assigning cells to groups...'
$assignResult = Invoke-McpTool -ToolName 'add-cells-to-group' -Arguments @{
    transactional = $true
    diagram_xml   = $xml
    assignments   = @(
        @{ cell_id = $groupIds['vnet']; group_id = $groupIds['student-rg'] }
        @{ cell_id = $groupIds['mgmt-subnet']; group_id = $groupIds['vnet'] }
        @{ cell_id = $groupIds['workload-subnet']; group_id = $groupIds['vnet'] }
    )
}
$xml = $assignResult.data.diagram_xml
Write-Host '  Groups nested successfully.'

# --- Step 5: Finish diagram ---
Write-Host '[6/7] Finishing diagram (resolving placeholders)...'
$finished = Invoke-McpTool -ToolName 'finish-diagram' -Arguments @{
    diagram_xml = $xml
    compress    = $false
}
$xml = $finished.data.xml
if (-not $xml) {
    $xml = $finished.data.diagram_xml
}
Write-Host '  Placeholders resolved.'

# --- Step 6: Export ---
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
