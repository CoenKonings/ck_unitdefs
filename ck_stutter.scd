/*
\ck_stutter
Simulate a broken audio driver control device. Grab and beat-repeat random
chunks of audio.

Rate: chance of grabbing a new audio chunk
Size: size of the audio chunk in seconds
Mix: dry/wet control.
*/
Udef(\ck_stutter, { |rate = 6, size = 0.08, mix = 1.0|
	var in, buf, frames, wp, trig, grab, startPt, rp, sig, window;
	in      = UIn.ar(0, 2);
	buf     = LocalBuf(SampleRate.ir * 0.5, 2).clear;
	frames  = BufFrames.kr(buf);
	wp      = Phasor.ar(0, 1, 0, frames);
	BufWr.ar(in, buf, wp);
	trig    = Dust.ar(rate);
	grab    = (size * SampleRate.ir);
	startPt = Latch.ar(wp - grab, trig);
	rp      = (Phasor.ar(0, 1, 0, grab) + startPt).wrap(0, frames);
	sig     = BufRd.ar(2, buf, rp, 1);
	UOut.ar(0, XFade2.ar(in, sig, (mix * 2 - 1)));
})
.category_(\glitch)
.setSpec(\rate, [0.1, 50, \exp, 0, 6].asSpec)
.setSpec(\size, [0.005, 0.5, \exp, 0, 0.08].asSpec)
.setSpec(\mix,  [0, 1, \lin, 0, 1].asSpec);
