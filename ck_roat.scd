/*
roat — "Rumble of Ancient Times" voice (after SOMA Labs RoAT)

8-bit noise source: four non-bandlimited oscillators, each with its own LFO
(tone or volume), combined in three pairwise nodes (1+2, 2+3, 3+4) with
selectable summing algorithms, then sample-rate-decimated and bit-crushed (the
"chip"), through a lo-fi resonant lowpass, then a per-trigger AR envelope with
a sustain floor.

The "chaos" control randomizes all parameters except oscillator pitch and main
amp.

wave (0-7): 0 saw 1 square 2 tri 3 sine 4 pulse25 5 varsaw 6 foldsine 7 noise
mode (0-7): 0 add 1 sub 2 ringmod 3 fm-ish 4 fold 5 xor(1-bit) 6 wrap 7 mod
*/

(
var def = Udef(\ck_roat, { |
		freq1 = 55, wave1 = 0, freq2 = 82.5, wave2 = 1,
		freq3 = 110, wave3 = 2, freq4 = 165, wave4 = 7,
		lfo1Rate = 2,  lfo1Depth = 0, lfo1Target = 0,
		lfo2Rate = 3, lfo2Depth = 0, lfo2Target = 0,
		lfo3Rate = 5, lfo3Depth = 0, lfo3Target = 0,
		lfo4Rate = 7,  lfo4Depth = 0, lfo4Target = 0,
		vol1 = 1, vol2 = 1, vol3 = 1, vol4 = 1,  // per-oscillator volumes
		modeAB = 0, modeBC = 0, modeCD = 0,
		cutoff = 1200, rq = 0.3,
		att = 0.005, rel = 0.6, sus = 1, amp = 1,
		chaos = 0 |

	var osc, voice, combine;
	var o1, o2, o3, o4, nAB, nBC, nCD, mix, levels, env, sig;

	osc = { |freq, wave|
		Select.ar(wave.clip(0, 7), [
			LFSaw.ar(freq),
			LFPulse.ar(freq, 0, 0.5) * 2 - 1,
			LFTri.ar(freq),
			SinOsc.ar(freq),
			LFPulse.ar(freq, 0, 0.25) * 2 - 1,
			VarSaw.ar(freq, 0, 0.2),
			(SinOsc.ar(freq).fold2(0.6) * 1.5),
			LFNoise0.ar(freq)
		]);
	};

	// Voice = oscillator + lfo.
	voice = { |freq, wave, lfoRate, lfoDepth, lfoTarget|
		var lfo = SinOsc.kr(lfoRate);
		var toneMul = Select.kr(lfoTarget, [1 + (lfo * lfoDepth), DC.kr(1)]);
		var volMul  = Select.kr(lfoTarget, [DC.kr(1), lfo.range(1 - lfoDepth, 1)]);
		osc.((freq * toneMul).max(1), wave) * volMul;
	};

	// Combine the signal of two voices.
	combine = { |a, b, mode|
		Select.ar(mode.clip(0, 7), [
			(a + b) * 0.5,  // Sum
			(a - b) * 0.5,  // Difference
			a * b,  // Amp mod
			SinOsc.ar(0, (a + b) * pi),  // Phase mod
			(a + b).fold2(0.7),  // Fold
			((((a > 0) + (b > 0)) % 2) * 2 - 1) * 0.8,  // 1-bit XOR of sign
			(a + b).wrap2(0.5),  // Wrap
			a % (b.abs + 0.2)  // Modulo
		]);
	};

	o1 = voice.(freq1, wave1, lfo1Rate, lfo1Depth, lfo1Target) * vol1.lag(0.01);
	o2 = voice.(freq2, wave2, lfo2Rate, lfo2Depth, lfo2Target) * vol2.lag(0.01);
	o3 = voice.(freq3, wave3, lfo3Rate, lfo3Depth, lfo3Target) * vol3.lag(0.01);
	o4 = voice.(freq4, wave4, lfo4Rate, lfo4Depth, lfo4Target) * vol4.lag(0.01);

	// Four signals (abcd) combined into three nodes (ab bc cd).
	nAB = combine.(o1, o2, modeAB);
	nBC = combine.(o2, o3, modeBC);
	nCD = combine.(o3, o4, modeCD);
	mix = (nAB + nBC + nCD) / 3;  // Unity mix

	// Bitcrush to simulate chip.
	levels = (2 ** 8).max(2);
	sig = Latch.ar(mix, Impulse.ar(8000));
	sig = (sig * (levels * 0.5)).round / (levels * 0.5);
	sig = RLPF.ar(sig.clip2(1), cutoff, rq);
	// Re-simulate chip after lowpass.
	sig = (sig * (levels * 0.5)).round / (levels * 0.5);
	env = EnvGen.kr(Env.perc(att, rel), doneAction: 0).max(sus);
	sig = (sig * env * amp).clip2(1);

	UMixOut.ar(0, sig, 0, true);
}).category_(\synthesis).setSpecMode(\amp, \normal);

[1, 2, 3, 4].do({ |i|
	def.setSpec(("freq" ++ i).asSymbol,         FreqSpec(19, 1350));
	def.setSpec(("wave" ++ i).asSymbol,         [0, 7, \lin, 1, 0].asSpec);
	def.setSpec(("lfo" ++ i ++ "Rate").asSymbol,   FreqSpec(0.01, 30, default: 2));
	def.setSpec(("lfo" ++ i ++ "Depth").asSymbol,  [0, 1, \lin, 0, 0].asSpec);
	def.setSpec(("lfo" ++ i ++ "Target").asSymbol, [0, 1, \lin, 1, 0].asSpec);
});

[\modeAB, \modeBC, \modeCD].do({ |k| def.setSpec(k, [0, 7, \lin, 1, 0].asSpec) });
def.setSpec(\cutoff, FreqSpec(60, 8000));
def.setSpec(\rq,    [0.05, 1,    \exp, 0, 0.3].asSpec);
def.setSpec(\att,   [0.001, 1,   \exp, 0, 0.005].asSpec);
def.setSpec(\rel,   [0.02, 8,    \exp, 0, 0.6].asSpec);
def.setSpec(\sus,   [0, 1,       \lin, 0, 1].asSpec);
[\vol1, \vol2, \vol3, \vol4].do({ |k| def.setSpec(k, [0, 1, \lin, 0, 1].asSpec) });

// Chaos button acts as a parameter randomizer.
def.setSpec(\chaos, TriggerSpec("chaos"));
def.showOnCollapse_([\chaos]);

// Randomize all parameters except oscillator pitches and UMap arguments.
def.prepareFunc_({ |servers, unit, action, startPos|
	Library.at( \ckRoatChaos, unit ) !? (_.remove);
	Library.put( \ckRoatChaos, unit, SimpleController( unit ) );
	Library.at( \ckRoatChaos, unit ).put( \chaos, { |obj, what, val|
		if( val > 0 ) {
			unit.argSpecs.do({ |argSpec|
				if(
					argSpec.private.not
					and: { argSpec.name != \chaos }
					and: { argSpec.name.asString.beginsWith("freq").not }
					and: { argSpec.name.asString.beginsWith("amp").not }
					// Keep routing.
					and: { argSpec.name.asString.beginsWith("u_").not }
					and: { argSpec.spec.notNil }
					// Keep sequenced arguments.
					and: { unit.get( argSpec.name ).isUMap.not }
				) {
					unit.set( argSpec.name, argSpec.spec.map( 1.0.rand ));
				};
			});
			unit.setArg( \chaos, 0 );  // Reset trigger.
		};
	});
	action.value;
});

def.uchainInitFunc_({ |unit, chain|
	// Arm at construction, so chaos works before the chain is played.
	def.prepareFunc.value( nil, unit, nil, nil );
	unit;
});

// When the chain is disposed, remove it from the Library as well.
def.disposeFunc_({ |unit|
	Library.at( \ckRoatChaos, unit ) !? (_.remove);
	Library.global.removeAtPath( [ \ckRoatChaos, unit ] );
});

def;
)
