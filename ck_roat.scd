/*
roat — "Rumble of Ancient Times" voice (after SOMA Labs RoAT)

An 8-bit noise source: four non-bandlimited oscillators, each with its own LFO
(modulating tone or volume), combined in three pairwise nodes (1+2, 2+3, 3+4)
each with a selectable summing algorithm, then sample-rate-decimated and
bit-crushed (the "chip"), through a lo-fi resonant lowpass, then a per-trigger
AR envelope with a sustain floor.

Pure DSP, no internal randomisation — every knob is a settable arg so that
randomisation/morph can write to it from the language and have the values
persist when you save the score. Mono source: append \stereoOutput in the chain.

  wave/mode indices (0-7):
   wave: 0 saw  1 square  2 tri  3 sine  4 pulse25  5 varsaw  6 foldsine  7 noise
   mode: 0 add  1 sub  2 ringmod  3 fm-ish  4 fold  5 xor(1-bit)  6 wrap  7 mod
*/

var def = Udef(\ck_roat, { |
        freq1 = 55,  wave1 = 0, lfo1Rate = 2,  lfo1Depth = 0, lfo1Target = 0,
        freq2 = 82.5, wave2 = 1, lfo2Rate = 3, lfo2Depth = 0, lfo2Target = 0,
        freq3 = 110, wave3 = 2, lfo3Rate = 5,  lfo3Depth = 0, lfo3Target = 0,
        freq4 = 165, wave4 = 7, lfo4Rate = 7,  lfo4Depth = 0, lfo4Target = 0,
        modeAB = 0, modeBC = 2, modeCD = 4,
        cutoff = 1200, rq = 0.3,
        srate = 8000, bits = 8,
        att = 0.005, rel = 0.6, sus = 1, amp = 0.3 |

    var osc, voice, combine;
    var o1, o2, o3, o4, nAB, nBC, nCD, mix, levels, env, sig;

    // --- one oscillator: pick a non-bandlimited waveform (aliasing is wanted) ---
    osc = { |freq, wave|
        Select.ar(wave.clip(0, 7), [
            LFSaw.ar(freq),
            LFPulse.ar(freq, 0, 0.5) * 2 - 1,
            LFTri.ar(freq),
            SinOsc.ar(freq),
            LFPulse.ar(freq, 0, 0.25) * 2 - 1,
            VarSaw.ar(freq, 0, 0.2),
            (SinOsc.ar(freq).fold2(0.6) * 1.5),
            LFNoise0.ar(freq)                       // stepped noise — RoAT grit
        ]);
    };

    // --- one voice: oscillator + its LFO (target 0 = tone, 1 = volume) ---
    voice = { |freq, wave, lfoRate, lfoDepth, lfoTarget|
        var lfo = SinOsc.kr(lfoRate);
        var toneMul = Select.kr(lfoTarget, [1 + (lfo * lfoDepth), DC.kr(1)]);
        var volMul  = Select.kr(lfoTarget, [DC.kr(1), lfo.range(1 - lfoDepth, 1)]);
        osc.((freq * toneMul).max(1), wave) * volMul;
    };

    // --- one node: combine two signals with a selectable algorithm ---
    combine = { |a, b, mode|
        Select.ar(mode.clip(0, 7), [
            (a + b) * 0.5,                                  // add
            (a - b) * 0.5,                                  // subtract
            a * b,                                          // ring mod / AM
            SinOsc.ar(0, (a + b) * pi),                     // FM-ish (phase mod)
            (a + b).fold2(0.7),                             // wavefold
            ((((a > 0) + (b > 0)) % 2) * 2 - 1) * 0.8,      // 1-bit XOR of signs
            (a + b).wrap2(0.5),                             // wrap glitch
            a % (b.abs + 0.2)                               // modulo glitch
        ]);
    };

    o1 = voice.(freq1, wave1, lfo1Rate, lfo1Depth, lfo1Target);
    o2 = voice.(freq2, wave2, lfo2Rate, lfo2Depth, lfo2Target);
    o3 = voice.(freq3, wave3, lfo3Rate, lfo3Depth, lfo3Target);
    o4 = voice.(freq4, wave4, lfo4Rate, lfo4Depth, lfo4Target);

    nAB = combine.(o1, o2, modeAB);
    nBC = combine.(o2, o3, modeBC);
    nCD = combine.(o3, o4, modeCD);
    mix = (nAB + nBC + nCD) / 3;

    // --- the "chip": decimate then bit-crush, applied to the combined signal ---
    levels = (2 ** bits).max(2);
    sig = Latch.ar(mix, Impulse.ar(srate.clip(200, 44100)));
    sig = (sig * (levels * 0.5)).round / (levels * 0.5);

    // --- lo-fi resonant lowpass, then re-crush its (resonant) output ---
    sig = RLPF.ar(sig.clip2(1), cutoff, rq);
    sig = (sig * (levels * 0.5)).round / (levels * 0.5);

    // --- per-trigger AR shape with a sustain floor (sus 1 = drone, 0 = pluck) ---
    // doneAction 0: timbral only; the chain (stereoOutput's UEnv) owns duration/fades.
    env = EnvGen.kr(Env.perc(att, rel), doneAction: 0).max(sus);
    sig = (sig * env * amp).clip2(1);

    UMixOut.ar(0, sig, 0, true);                            // mono source
}).category_(\synthesis).setSpecMode(\amp, \normal);

// specs drive the GUI editors; loop the per-oscillator ones to stay consistent
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
def.setSpec(\srate, [500, 20000, \exp, 0, 8000].asSpec);
def.setSpec(\bits,  [2, 12,      \lin, 1, 8].asSpec);
def.setSpec(\att,   [0.001, 1,   \exp, 0, 0.005].asSpec);
def.setSpec(\rel,   [0.02, 8,    \exp, 0, 0.6].asSpec);
def.setSpec(\sus,   [0, 1,       \lin, 0, 1].asSpec);

def;
