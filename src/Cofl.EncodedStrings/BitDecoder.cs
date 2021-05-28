using System;
using System.Collections.Generic;

namespace Cofl.EncodedStrings
{
    public struct BitDecoder
    {
        public bool IsInitialized => null != Alphabet;
        private readonly Dictionary<char, ulong> Alphabet;
        private readonly byte CharacterBitWidth;
        private readonly bool HasPadding;
        private readonly char PaddingCharacter;

        public BitDecoder(char[] alphabet, char paddingCharacter): this(alphabet)
        {
            HasPadding = true;
            PaddingCharacter = paddingCharacter;
            foreach(var a in alphabet)
                if(a == paddingCharacter)
                    throw new ArgumentException(paramName: nameof(paddingCharacter), message: "Padding character cannot be a member of the alphabet.");
        }

        public BitDecoder(char[] alphabet)
        {
            var valid = EncodedString.TestValidAlphabet(alphabet);
            if(AlphabetValidity.Valid != valid)
                throw new ArgumentException(paramName: nameof(alphabet), message: valid.ToString());
            CharacterBitWidth = (byte) Math.Log(alphabet.Length, 2);
            Alphabet = new Dictionary<char, ulong>();
            for(var i = 0L; i < alphabet.LongLength; i += 1)
                Alphabet[alphabet[i]] = (ulong) i;
            HasPadding = false;
            PaddingCharacter = '\0';
        }

        public IEnumerable<byte> Decode(IEnumerable<char> source)
        {
            var buffer = 0ul;
            var availableBits = 0;
            foreach(var sourceChar in source)
            {
                if(HasPadding && sourceChar == PaddingCharacter)
                    break;
                buffer = (buffer << CharacterBitWidth) | Alphabet[sourceChar];
                availableBits += CharacterBitWidth;
                while(availableBits >= 8)
                {
                    availableBits -= 8;
                    yield return unchecked((byte)(buffer >> availableBits));
                }
            }

            if(availableBits > 0)
                yield return unchecked((byte)(buffer << (8 - availableBits)));
        }
    }
}
