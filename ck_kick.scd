/*
\ck_simple_kick.scd

A simple kick based on a sine with a pitch and amp envelope routed through tanh
distortion.
*/

Udef(\ck_simple_kick,{ | ampDecay = 0.5, freqDecay = 0.2, preAmp = 1.0, amp = 1.0, freq = 55, click = 100|
	var trig, sig, ampEnv, pitchEnv;

	trig = \trigger.tr(1);

	ampEnv = EnvGen.ar(Env.perc(0.01, ampDecay), trig);
	pitchEnv = EnvGen.ar(Env.perc(0.01, freqDecay), trig);

	sig = SinOsc.ar(freq + (click * pitchEnv));
	sig = sig * ampEnv;
	sig = (sig * preAmp).tanh * amp;

	UMixOut.ar(0, sig, 0, true);

}).category_( \synthesis )
	.setSpec( \trigger, TriggerSpec() )
	.setSpec( \freqDecay, [0.01,10,\exp, 0, 0.2].asSpec )
	.setSpec( \ampDecay, [0.01,10,\exp, 0, 0.5].asSpec )
	.setSpec( \preAmp, [0.5, 20, \exp, 0, 1].asSpec )
	.setSpec( \click, [0, 500, 4.0, 0, 100].asSpec );
