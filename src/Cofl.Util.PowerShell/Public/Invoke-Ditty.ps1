# TODO: documentation
function Invoke-Ditty {
    [CmdletBinding(DefaultParameterSetName='Duration')]
    PARAM (
        [Parameter(Mandatory,ValueFromRemainingArguments,ValueFromPipeline,Position=0)]
            [AllowEmptyCollection()]
            [string[]]$Notes,
        [Parameter(ParameterSetName='Duration')][int]$BaseDuration = 225,
        [Parameter(ParameterSetName='BPM',Mandatory)][int]$BPM,
        [Parameter(ParameterSetName='BPM')][ValidateSet(32,16,8,4)]$BaseNote = 'quarter'
    )

    begin {
        $NoteNames = @{
            'B8' = 7902
            'A#8' = 7459
            'A8' = 7040
            'G#8' = 6645
            'G8' = 6272
            'F#8' = 5920
            'F8' = 5588
            'E8' = 5274
            'D#8' = 4978
            'D8' = 4699
            'C#8' = 4435
            'C8' = 4186

            'B7' = 3951
            'A#7' = 3729
            'A7' = 3520
            'G#7' = 3322
            'G7' = 3136
            'F#7' = 2960
            'F7' = 2794
            'E7' = 2637
            'D#7' = 2489
            'D7' = 2349
            'C#7' = 2217
            'C7' = 2093

            'B6' = 1976
            'A#6' = 1865
            'A6' = 1760
            'G#6' = 1661
            'G6' = 1568
            'F#6' = 1480
            'F6' = 1397
            'E6' = 1319
            'D#6' = 1245
            'D6' = 1175
            'C#6' = 1109
            'C6' = 1047

            'B5' = 988
            'A#5' = 932
            'A5' = 880
            'G#5' = 831
            'G5' = 784
            'F#5' = 740
            'F5' = 698
            'E5' = 659
            'D#5' = 622
            'D5' = 587
            'C#5' = 554
            'C5' = 523

            'B4' = 494
            'A#4' = 466
            'A4' = 440
            'G#4' = 415
            'G4' = 392
            'F#4' = 370
            'F4' = 349
            'E4' = 330
            'D#4' = 311
            'D4' = 294
            'C#4' = 277
            'C4' = 262

            'B' = 494
            'A#' = 466
            'A' = 440
            'G#' = 415
            'G' = 392
            'F#' = 370
            'F' = 349
            'E' = 330
            'D#' = 311
            'D' = 294
            'C#' = 277
            'C' = 262

            'B3' = 247
            'A#3' = 233
            'A3' = 220
            'G#3' = 208
            'G3' = 196
            'F#3' = 185
            'F3' = 175
            'E3' = 165
            'D#3' = 156
            'D3' = 147
            'C#3' = 139
            'C3' = 131

            'B2' = 123
            'A#2' = 117
            'A2' = 110
            'G#2' = 104
            'G2' = 98
            'F#2' = 92
            'F2' = 87
            'E2' = 82
            'D#2' = 78
            'D2' = 73
            'C#2' = 69
            'C2' = 65

            'B1' = 62
            'A#1' = 58
            'A1' = 55
            'G#1' = 52
            'G1' = 49
            'F#1' = 46
            'F1' = 44
            'E1' = 41
            'D#1' = 39
            'D1' = 37
            'C#1' = 35
            'C1' = 33

            'B0' = 31
            'A#0' = 29
            'A0' = 28
            'p' = -1
        }
        if($BPM){
            $Multiplier = switch ($BaseNote) {
                32 { 8 }
                16 { 4 }
                8 { 2 }
                default { 1 }
            }
            $BaseDuration = [timespan]::TicksPerMinute/[timespan]::TicksPerMillisecond/$BPM/$Multiplier
        }
    }

    process {
        foreach($Stanza in $Notes){
            foreach($Note in $Stanza -split '[\s|,]+' | Where-Object { $_ }){
                $Duration = $BaseDuration
                if($Note -match '(-+)(\d+)?$'){
                    $Note = $Note -replace '-.*$'
                    if($Matches.ContainsKey(2)){
                        $Duration = $Matches[1].Length * [int]$Matches[2]
                    } else {
                        $Duration *= $Matches[1].Length
                    }
                }
                if($NoteNames.ContainsKey($Note)){
                    $Note = $NoteNames[$Note]
                } else {
                    $Note = [int]$Note
                }

                if($Note -lt 0){
                    Start-Sleep -Milliseconds $Duration
                } else {
                    [Console]::Beep($Note, $Duration)
                }
            }
        }
    }
}
