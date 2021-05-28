using System;
using System.Management.Automation;
using System.Collections.Generic;

namespace Cofl.EncodedStrings
{
    internal class ValidateValidAlphabetAttribute : ValidateArgumentsAttribute
    {
        protected override void Validate(object argument, EngineIntrinsics engineIntrinsics)
        {
            if(!(argument is string str))
                throw new ArgumentException("Invalid type.", nameof(argument));
            if(str.Length < 2)
                throw new ArgumentOutOfRangeException(nameof(argument), "Alphabet is too short (must be 2 characters or longer)");
            if(Math.Log(str.Length, 2) % 1 != 0)
                throw new ArgumentOutOfRangeException(nameof(argument), "Alphabet length is not a power of 2.");
            var duplicates = new HashSet<char>();
            var characters = new HashSet<char>();
            foreach(var character in str.ToCharArray())
                if(!characters.Add(character))
                    duplicates.Add(character);
            if(duplicates.Count > 0)
                throw new ArgumentException("Alphabet has duplicate characters: " + string.Join(",", duplicates));
        }
    }
}
