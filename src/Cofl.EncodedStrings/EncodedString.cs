using System;
using System.Collections.Generic;

namespace Cofl.EncodedStrings
{
    public static class EncodedString
    {
        public static AlphabetValidity TestValidAlphabet(char[] alphabet)
        {
            if(alphabet.Length < 2)
                return AlphabetValidity.TooShort;
            if(alphabet.LongLength > (1u << 31))
                return AlphabetValidity.TooLong;
            if(0 != Math.Log(alphabet.LongLength, 2) % 1)
                return AlphabetValidity.NonTwoPowerLength;
            
            var set = new HashSet<char>();
            foreach(var character in alphabet)
                if(!set.Add(character))
                    return AlphabetValidity.DuplicateEntry;
            return AlphabetValidity.Valid;
        }
    }
}
