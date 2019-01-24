function Say-String
{
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseApprovedVerbs', '')]
    [CmdletBinding()]
    PARAM(
        [Parameter()][ValidateSet('David', 'Zira')][string]$Voice = 'Zira',
        [Parameter()][string]$ComputerName = '',
        [Parameter(Mandatory=$true,ParameterSetName='String',ValueFromPipeline=$true,Position=0,ValueFromRemainingArguments=$true)][string[]]$Strings,
        [Parameter(Mandatory=$true,ParameterSetName='Time')][switch]$Time
    )

    begin
    {
        $Remoting = ![string]::IsNullOrWhiteSpace($ComputerName)
        if($Remoting){
            $Session = New-PSSession -ComputerName $ComputerName
            Invoke-Command -Session $Session {
                [void][reflection.assembly]::LoadWithPartialName('System.Speech')
                $Speaker = [System.Speech.Synthesis.SpeechSynthesizer]::new()
                if($using:Voice -eq 'Zira')
                {
                    $Speaker.SelectVoiceByHints([System.Speech.Synthesis.VoiceGender]::Female)
                } else
                {
                    $Speaker.SelectVoiceByHints([System.Speech.Synthesis.VoiceGender]::Male)
                }
            }
        } else
        {
            [void][reflection.assembly]::LoadWithPartialName('System.Speech')
            $Speaker = [System.Speech.Synthesis.SpeechSynthesizer]::new()
            if($Voice -eq 'Zira')
            {
                $Speaker.SelectVoiceByHints([System.Speech.Synthesis.VoiceGender]::Female)
            } else
            {
                $Speaker.SelectVoiceByHints([System.Speech.Synthesis.VoiceGender]::Male)
            }
        }
    }

    process
    {
        if($PSCmdlet.ParameterSetName -eq 'Time')
        {
            $Strings = [string[]]@("It is now $((Get-Date).ToShortTimeString())")
        }

        if($Remoting)
        {
            Invoke-Command -Session $Session {
                foreach($String in $using:Strings)
                {
                    $Speaker.Speak($String)
                }
            }
        } else
        {
            foreach($String in $Strings)
            {
                $Speaker.Speak($String)
            }
        }
    }

    end
    {
        if($Remoting)
        {
            Invoke-Command -Session $Session {
                $Speaker.Dispose()
            }
            Remove-PSSession -Session $Session
        } else
        {
            $Speaker.Dispose()
        }
    }
}
