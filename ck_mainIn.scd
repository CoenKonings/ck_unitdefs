MultiChannelUdef( "mainIn", { |bus = 0|
	var input;
	input = In.ar( bus, Udef.numChannels );
	ReplaceOut.ar( bus, Silent.ar.dup( Udef.numChannels ) );
	UOut.ar( 0, input );
}).setSpec( \bus, IntegerSpec(0,0,512) ).category_( \input );
