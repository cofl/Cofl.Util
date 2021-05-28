using System;
using Encoding = System.Text.Encoding;
using System.Management.Automation;
using System.Linq;

namespace Cofl.EncodedStrings
{
    [Cmdlet(VerbsData.ConvertFrom, "EncodedString", DefaultParameterSetName = "Padding")]
    [OutputType(typeof(string))]
    public sealed class ConvertFromEncodedStringCmdlet: Cmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        [Alias("String")]
        [AllowEmptyString]
        public string InputString { get; set; }

        [Parameter]
        public Encoding Encoding { get; set; } = Encoding.UTF8;

        [Parameter]
        [ValidateValidAlphabet]
        public string Alphabet { get; set; }

        [Parameter(ParameterSetName = "Padding")]
        public char PaddingCharacter { get; set; } = '=';

        [Parameter(ParameterSetName = "NoPadding")]
        public SwitchParameter NoPadding { get; set; }

        private BitDecoder Decoder;
        protected override void BeginProcessing()
        {
            if(null == Encoding)
                Encoding = Encoding.UTF8;
            if(null == Alphabet)
                return;
            
            if(NoPadding.IsPresent)
                Decoder = new BitDecoder(Alphabet.ToCharArray());
            else
                Decoder = new BitDecoder(Alphabet.ToCharArray(), PaddingCharacter);
        }

        protected override void ProcessRecord()
        {
            if(!Decoder.IsInitialized)
            {
                WriteObject(Encoding.GetString(Convert.FromBase64String(InputString)));
                return;
            }

            WriteObject(Encoding.GetString(Decoder.Decode(InputString).ToArray()));
        }
    }
}
