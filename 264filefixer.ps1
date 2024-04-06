
param (
    [string]$InputFolderPath,
    [string]$OutputFolderPath,
    [string]$FileExt
)

Function FixIt($filename,$output)
{
    [byte[]]$HXVS = 0x48, 0x58, 0x56, 0x53
    [byte[]]$HXVF = 0x48, 0x58, 0x56, 0x46
    [byte[]]$HXAF = 0x48, 0x58, 0x41, 0x46
    [byte[]]$HXFI = 0x48, 0x58, 0x46, 0x49
    #input: A filename (string -- complete Path) in the variable $filename.
    #$output A filename (string -- complete Path) in the variable $output
      
    if (-not (Test-Path $output -PathType Leaf)) 
    { 

        $Input           = [System.IO.File]::OpenRead($filename)
        [byte[]]$header  = @(0)*16
        [byte[]]$payload = @(0)*1048576
        $out   = [System.IO.File]::Create($output)
                      
        While (($Input.Position+16) -le $Input.Length)
        {
            $Null = $Input.Read($header,0,16)
            $length = [System.BitConverter]::ToUInt32($header,4)
            if (($header[0] -eq $HXVF[0]) -and ($header[1] -eq $HXVF[1]) -and ($header[2] -eq $HXVF[2]) -and ($header[3] -eq $HXVF[3]))
            {
                $Null   = $Input.Read($payload,0,$length)
                if (-not(($payload[0] -eq [byte]0x00) -and ($payload[1] -eq [byte]0x00) -and (($payload[2] -eq [byte]0x01) -or (($payload[2] -eq [byte]0x00) -and ($payload[3] -eq [byte]0x01)))))
                {
                    Write-Error "No valid H.264 start code found at position ($Input.Position)."
                    $Input.Close
                    $out.Close
                    Break
                }
                $out.Write($payload,0,$length)
            }
            elseif (($header[0] -eq $HXAF[0]) -and ($header[1] -eq $HXAF[1]) -and ($header[2] -eq $HXAF[2]) -and ($header[3] -eq $HXAF[3]))
            {
                $Input.Position += $length # Padding
            }
            elseif (($header[0] -eq $HXFI[0]) -and ($header[1] -eq $HXFI[1]) -and ($header[2] -eq $HXFI[2]) -and ($header[3] -eq $HXFI[3]))
            {
                Break
            }
            elseif (($header[0] -ne $HXVS[0]) -or ($header[1] -ne $HXVS[1]) -or ($header[2] -ne $HXVS[2]) -or ($header[3] -ne $HXVS[3]))
            {
                Write-Error "Unknown header found at position ($Input.Position-16). Header:"+([System.BitConverter]::ToString($header))
                Break
            }
        }
        $Input.Close()
        $out.Close()

        #Output to the host that each file has been processed. 
        Write-Host "$output processed"

    }else
    {
        Write-Host "$output has already been processed, skipping"
    }


}

#Check if all parameters are provided
if (-not ($InputFolderPath -and $OutputFolderPath)) 
{
    Write-Host ""
    Write-Host "Usage: Fix264Files.ps1 -InputFolderPath <input_folder_path> -OutputFolderPath <output_folder_path> "
    Write-Host ""
    exit
}



# Check if the input folder path exists
if (-not (Test-Path $InputFolderPath -PathType Container)) 
{
    Write-Host "$InputFolderPath does not exist."
    exit
}

# Check if the output folder path exists
if (-not (Test-Path $OutputFolderPath -PathType Container)) 
{
    Write-Host "$OutputFolderPath does not exist."
    exit
}



# Get all .264 files in the folder
$files = Get-ChildItem -Path $InputFolderPath -Filter "*.264" -File

# Loop through each file
foreach ($file in $files) 
{
    #Create Output Filepath
    $OutputFullPath =(Resolve-Path $OutputFolderPath).Path+'\'+[System.IO.Path]::GetFileNameWithoutExtension($file.Name)+".fixed.264"

    #Call Fixit Function to fix each file
    FixIt $file.FullName $OutputFullPath
}



