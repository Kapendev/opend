/*

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license ( the "Software" ) to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/
module derelict.util.exception;

/++
 Base class for all exceptions thrown by Derelict packages.
+/
class DerelictException : Exception {
    public this( string msg ) {
        super( msg );
    }
}

/++
 Helper struct to facilitate throwing a single SharedLibException after failing
 to load a library using multiple names.
+/
private struct FailedSharedLib {
    string name;
    string reason;
}

/++
 This exception is thrown when a shared library cannot be loaded
 because it is either missing or not on the system path.
+/
class SharedLibLoadException : DerelictException
{
    private string _sharedLibName;

    public {
        static void throwNew( in char[][] libNames, in char[][] reasons ) {
            string msg = "Failed to load one or more shared libraries:";
            foreach( i, n; libNames ) {
                msg ~= "\n\t" ~ n ~ " - ";
                if( i < reasons.length )
                    msg ~= reasons[i];
                else
                    msg ~= "Unknown";
            }
            throw new SharedLibLoadException( msg );
        }

        this( string msg ) {
            super( msg );
            _sharedLibName = "";
        }

        this( string msg, string sharedLibName ) {
            super( msg );
            _sharedLibName = sharedLibName;
        }

        string sharedLibName() {
            return _sharedLibName;
        }
    }
}

/++
 This exception is thrown when a symbol cannot be loaded from a shared library,
 either because it does not exist in the library or because the library is corrupt.
+/
class SymbolLoadException : DerelictException
{
    private string _symbolName;

    public {
        this( string msg ) {
            super( msg );
        }

        this( string sharedLibName, string symbolName ) {
            super( "Failed to load symbol " ~ symbolName ~ " from shared library " ~ sharedLibName );
            _symbolName = symbolName;
        }

        string symbolName() {
            return _symbolName;
        }
    }
}

/++
 The return type of the MissingSymbolCallbackFunc/Dg.
+/
enum ShouldThrow {
    No,
    Yes
}

/++
 The MissingSymbolCallback allows the prevent the throwing of SymbolLoadExceptions.

 By default, a SymbolLoadException is thrown when a symbol cannot be found in a shared
 library. Assigning a MissingSymbolCallback to a loader allows the application to override
 this behavior. If the missing symbol in question can be ignored, the callback should
 return ShouldThrow.No to prevent the exception from being thrown. Otherwise, the
 return value should be ShouldThrow.Yes. This is useful to allow a binding implemented
 for version N.N of a library to load older or newer versions that may be missing
 functions the loader expects to find, provided of course that the app does not need
 to use those functions.
+/
alias MissingSymbolCallbackFunc = ShouldThrow function( string symbolName );
/// Ditto
alias MissingSymbolCallbackDg = ShouldThrow delegate( string symbolName );
