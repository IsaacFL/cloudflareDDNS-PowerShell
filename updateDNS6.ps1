[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

##### Config Params
$what_ip = "internal"                                              ##### Which IP should be used for the record: internal only for ipv6
$what_interface = "Ethernet"                                       ##### For internal IP, provide interface name
$dns_record = "ddns.example.com"                                        ##### DNS AAAA record which will be updated
$zoneid = "ChangeMe"                        ##### Cloudflare's Zone ID
$proxied = $false                                                  ##### Use Cloudflare proxy on dns record true/false
$ttl = 1                                                          ##### 120-7200 in seconds or 1 for Auto
$cloudflare_api_token = "ChangeMe"  ##### Cloudflare API Token keep it private!!!!
  
##### updateDNS.log file of the last run for debug
$File_LOG = "$PSScriptRoot\.updateDNS.log"
$FileName = ".updateDNS.log"

##### DNS Record Type AAAA
$type = "AAAA"

if (!(Test-Path $File_LOG)) {
    New-Item -ItemType File -Path $PSScriptRoot -Name ($FileName) | Out-Null
}

$DATE = Get-Date -UFormat "%Y/%m/%d %H:%M:%S"

if ($what_ip -eq 'external') {
    $ip = Invoke-RestMethod -Uri "https://ipv6.whatismyip.host/"
    $ip = $ip.Trim()
}
elseif ($what_ip -eq 'internal') {
    $response = Get-NetIPAddress -AddressFamily IPv6 -InterfaceAlias $what_interface -SuffixOrigin "Link" -PrefixOrigin "RouterAdvertisement"
    $ip = $response.IPAddress.Trim()
}
else {
    Write-Output "$DATE ==> missing or incorrect what_ip/what_interface parameter" 
}
Write-Output "$DATE ==> Extracted IP is $ip" | Tee-Object $File_LOG -Append



##### get the dns record id and current ip from cloudflare's api
$dns_record_info = @{
    Uri     = "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=$type&name=$dns_record"
    Headers = @{"Authorization" = "Bearer $cloudflare_api_token"; "Content-Type" = "application/json" }
}

$response = Invoke-RestMethod @dns_record_info
$dns_record_id = $response.result[0].id.Trim()
$dns_record_ip = $response.result[0].content.Trim()


if ( $dns_record_ip -eq $ip) {
    Write-Output "$DATE ==> No changes needed! DNS Record currently is set to $dns_record_ip" | Tee-Object $File_LOG -Append
    Exit
}
else {
    Write-Output "$DATE ==> DNS Record currently is set to $dns_record_ip. Updating!!!" | Tee-Object $File_LOG -Append
}

##### updates the dns record

$updateRecord = @{
    Uri     = "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dns_record_id"
    Method  = 'PUT'
    Headers = @{"Authorization" = "Bearer $cloudflare_api_token"; "Content-Type" = "application/json" }
    Body    = @{
        "type"    = $type
        "name"    = $dns_record
        "content" = $ip
        "ttl"     = $ttl
        "proxied" = $proxied
    } | ConvertTo-Json
}


$response = Invoke-RestMethod @updateRecord

if ($response.success -eq "True") {
    Write-Output "$DATE ==> $dns_record DNS Record Updated To: $ip" | Tee-Object $File_LOG -Append
    Exit
}
else {
    Write-Output "$DATE ==> FAILED $response" | Tee-Object $File_LOG -Append
    
}
