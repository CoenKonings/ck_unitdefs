// ck_garbage — byte misalignment: folds and noise-corrupts the signal, gated against the dry
Udef(\ck_garbage, { |prob = 0.2, rate = 8, mix = 1.0|
	var in, amp, noise, gate, sig;
	in    = UIn.ar(0, 2);
	amp   = Amplitude.ar(in);
	noise = PinkNoise.ar(amp * 4) + (in * 8).fold(-1, 1);
	gate  = ToggleFF.ar(CoinGate.ar(prob, Impulse.ar(rate)));
	sig   = Select.ar(gate, [in, noise.tanh]);
	UOut.ar(0, XFade2.ar(in, sig, (mix * 2 - 1)));
})
	.category_(\glitch)
	.setSpec(\prob, [0, 1, \lin, 0, 0.2].asSpec)
	.setSpec(\rate, [0.1, 50, \exp, 0, 8].asSpec)
	.setSpec(\mix,  [0, 1, \lin, 0, 1].asSpec);
