using namespace System.Speech.Synthesis

function Invoke-Speech
{
    [CmdletBinding(DefaultParameterSetName='String')]
    PARAM(
        [Parameter()][ValidateSet('David', 'Zira')][string]$Voice = 'Zira',
        [Parameter(Mandatory=$true,ParameterSetName='String',ValueFromPipeline=$true,Position=0,ValueFromRemainingArguments=$true)][string[]]$String,
        [Parameter(Mandatory=$true,ParameterSetName='Prompt',ValueFromPipeline=$true,Position=0,ValueFromPipelineByPropertyName=$true)][Prompt[]]$Prompt,
        [Parameter(Mandatory=$true,ParameterSetName='SSML',ValueFromPipeline=$true,Position=0,ValueFromPipelineByPropertyName=$true)][string[]]$SSMLString,
        [Parameter(Mandatory=$true,ParameterSetName='Time')][switch]$Time
    )

    begin
    {
        $Speaker = [SpeechSynthesizer]::new()
        if($Voice -eq 'Zira')
        {
            $Speaker.SelectVoiceByHints([VoiceGender]::Female)
        } else
        {
            $Speaker.SelectVoiceByHints([VoiceGender]::Male)
        }
    }

    process
    {
        $Type = $PSCmdlet.ParameterSetName
        if($Type -eq 'Time')
        {
            $String = [string[]]@("It is now $((Get-Date).ToShortTimeString())")
            $Type = 'String'
        }

        switch -Exact ($Type)
        {
            'String'
            {
                foreach($Item in $String)
                {
                    $Speaker.Speak($Item)
                }
            }

            'Prompt'
            {
                foreach($Item in $Prompt)
                {
                    $Speaker.Speak($Item)
                }
            }

            'SSML'
            {
                foreach($Item in $SSMLString)
                {
                    if($Item)
                    {
                        $Speaker.SpeakSsml($Item)
                    }
                }
            }
        }
    }

    end
    {
        $Speaker.Dispose();
    }
}
