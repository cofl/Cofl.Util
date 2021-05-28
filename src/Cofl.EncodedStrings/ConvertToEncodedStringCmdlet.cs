using System;
using System.Text;
using System.Management.Automation;

namespace Cofl.EncodedStrings
{
    [Cmdlet(VerbsData.ConvertTo, "EncodedString", DefaultParameterSetName = "Padding")]
    [OutputType(typeof(string))]
    public sealed class ConvertToEncodedStringCmdlet: Cmdlet
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

        private BitEncoder Encoder;
        protected override void BeginProcessing()
        {
            if(null == Encoding)
                Encoding = Encoding.UTF8;
            if(null == Alphabet)
                return;

            if(NoPadding.IsPresent)
                Encoder = new BitEncoder(Alphabet.ToCharArray());
            else
                Encoder = new BitEncoder(Alphabet.ToCharArray(), PaddingCharacter);
        }

        protected override void ProcessRecord()
        {
            if(!Encoder.IsInitialized)
            {
                WriteObject(Convert.ToBase64String(Encoding.GetBytes(InputString)));
                return;
            }

            var builder = new StringBuilder();
            foreach(var character in Encoder.Encode(Encoding.GetBytes(InputString)))
                builder.Append(character);
            WriteObject(builder.ToString());
        }
    }
}
