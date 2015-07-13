
// blackrain - 2008

SpawnBlock	: InfoUGenBase {}	// ir
SpawnOffset	: InfoUGenBase {}	// ir

BlockCount	: UGen {
	*kr {
		^this.multiNew('control')
	}
}

BlockOffset	: UGen {
	*ar {
		^this.multiNew('audio')
	}
}

ImpulseDriver : UGen {
	*ar { arg samples = 44100;
		^this.multiNew('audio', samples)
	}
}
