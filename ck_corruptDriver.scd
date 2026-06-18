/*
Simulate audio driver parsing errors. Bitcrushing, noise bursts
*/

Udef(\ck_corruptDriver, { |rate = 8, noise = 0.4, bits = 6, mix = 1.0|
	var in, gate, levels, crushed, burst, sig;
	in = UIn.ar(0, 2);
	gate = ToggleFF.kr(Dust.kr(rate));
	levels = 2 ** bits;
	crushed = (in * levels).round(1) / levels;
	burst = (PinkNoise.ar(1) ! 2) * EnvGen.kr(Env.perc(0.001, 0.01), Dust.kr(rate * 0.7)) * noise;
	sig = (crushed * gate) + burst;
	UOut.ar(0, Limiter.ar(XFade2.ar(in, sig, (mix * 2 - 1)), 0.97));
})
	.category_(\glitch).setSpec(\rate,  [0.1, 50, \exp, 0, 8].asSpec)
	.setSpec(\noise, [0, 1, \lin, 0, 0.4].asSpec)
	.setSpec(\bits,  [1, 16, \lin, 1, 6].asSpec)
	.setSpec(\mix,   [0, 1, \lin, 0, 1].asSpec);
