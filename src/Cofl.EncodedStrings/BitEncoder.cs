using System;
using System.Collections.Generic;

namespace Cofl.EncodedStrings
{
    public struct BitEncoder
    {
        public bool IsInitialized => null != Alphabet;
        private readonly char[] Alphabet;
        private readonly byte CharacterBitWidth;
        private readonly bool HasPadding;
        private readonly char PaddingCharacter;
        private readonly int CharactersToMatchByteLength;
        private readonly ulong Mask;

        public BitEncoder(char[] alphabet, char paddingCharacter): this(alphabet)
        {
            HasPadding = true;
            PaddingCharacter = paddingCharacter;
            foreach(var a in alphabet)
                if(a == paddingCharacter)
                    throw new ArgumentException(paramName: nameof(paddingCharacter), message: "Padding character cannot be a member of the alphabet.");
        }

        public BitEncoder(char[] alphabet)
        {
            var valid = EncodedString.TestValidAlphabet(alphabet);
            if(AlphabetValidity.Valid != valid)
                throw new ArgumentException(paramName: nameof(alphabet), message: valid.ToString());
            Alphabet = alphabet;
            CharacterBitWidth = (byte) Math.Log(alphabet.Length, 2);
            Mask = unchecked((1ul << CharacterBitWidth) - 1);

            int a = 0;
            CharactersToMatchByteLength = 0;
            do {
                a += CharacterBitWidth;
                CharactersToMatchByteLength += 1;
            } while(a % 8 != 0);

            HasPadding = false;
            PaddingCharacter = '\0';
        }

        public IEnumerable<char> Encode(IEnumerable<byte> source)
        {
            var emittedCharacters = 0ul;
            var buffer = 0ul;
            var availableBits = 0;
            foreach(var sourceByte in source)
            {
                buffer = (buffer << 8) | sourceByte;
                availableBits += 8;
                while(availableBits >= CharacterBitWidth)
                {
                    availableBits -= CharacterBitWidth;
                    emittedCharacters += 1;
                    yield return Alphabet[(buffer >> availableBits) & Mask];
                }
            }

            if(availableBits > 0)
                yield return Alphabet[(buffer << (CharacterBitWidth - availableBits)) & Mask];
            
            if(HasPadding)
            {
                var paddingCharacters = (ulong)CharactersToMatchByteLength - emittedCharacters % (ulong)CharactersToMatchByteLength;
                while(paddingCharacters --> 0)
                    yield return PaddingCharacter;
            }
        }
    }
}
