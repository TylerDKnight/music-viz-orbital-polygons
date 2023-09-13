// starmode threshold is kind of a race condition
// decay rate varies by resolution, cpu, decay recurrence
// consider a metric that is based on framerate 

import ddf.minim.*;
import ddf.minim.analysis.*;

Minim minim;
AudioInput in;
BeatDetect beat;
FFT fft;

int numOrbiting = 5;  // Number of orbiting polygons
float centerSize;
float[] orbitingSizes = new float[numOrbiting];
ArrayList<SmokeRing> smokeRings = new ArrayList<SmokeRing>();
float maxScaleEver = 0;
boolean starMode = false;
float phaseDuration = 1;
int starModeDuration = 0;
int starSides = 0;

void setup() {
  size(300, 300);
  //fullScreen(2);
  frameRate(120);
  minim = new Minim(this);
  in = minim.getLineIn(Minim.MONO);
  beat = new BeatDetect();
  //beat.detectMode(BeatDetect.SOUND_ENERGY);
  beat.detectMode(BeatDetect.FREQ_ENERGY);
  //beat.isOnset(10, 20);
  beat.setSensitivity(250);
  minim.debugOn();
  fft = new FFT(in.bufferSize(), in.sampleRate());
  centerSize = height * 0.25; // Initial size of the center polygon
  for (int i = 0; i < numOrbiting; i++) {
    //orbitingSizes[i] = height * 0.1;
    
    //orbitingSizes[i] = height * 0.1 / (numOrbiting / 4) - ((i-3) * 4); // Initial sizes for orbiting polygons
    // First term: % of screen height
    // Second term: adjust spacing between orbiters
    // Third term: shrink each orbiter a little bit to make a spiral
    
    orbitingSizes[i] = 0.1 * (2 * centerSize * sin( 360 / (2 * numOrbiting) ) ) + (i * 0.3);
    // Orbit size based on central polygon side length
  }
  noFill();
  stroke(255);
}

class SmokeRing {
  float scale;
  float alpha;
  float rotation;
  float rotationSpeed;
  int framesAlive;

  SmokeRing(float initialScale, float initialRotation, float initialRotationSpeed, float initialAlpha) {
    this.scale = initialScale;
    this.rotation = initialRotation;
    this.rotationSpeed = initialRotationSpeed; // Unused bc star mode
    this.alpha = initialAlpha;
    this.framesAlive = 0;
  }

  void update() {
    alpha *= 0.93;
    scale *= 0.95;
    rotation += PI / 150;
    //rotation += rotationSpeed;
    framesAlive += 1;
  }

  boolean isFaded() {
    return alpha < 10;
  }
}

int getLogarithmicBand(int index, int maxIndex, float maxFrequency, float sampleRate) {
    float minLog = log(1);
    float maxLog = log(maxFrequency);
    float scale = (maxLog - minLog) / maxIndex;

    int band = int(exp(minLog + scale * index) * fft.specSize() / sampleRate);
    return constrain(band, 0, fft.specSize() - 1);
}


void draw() {
  background(0);

  // Update beat detection and fft
  beat.detect(in.mix);
  fft.forward(in.mix);
  
  // Debug beat detection
  //println(millis() + " " + in.mix.get(0));
  //println(fft.getBand(0) > 0.002, nf(fft.getBand(10), 0, 4), nf(100 * fft.getBand(20), 0, 4));
  //println(beat.isOnset());

  
  // Center Polygon
  float centerRotationSpeed = PI / 300; // Speed of rotation
  int centerSides = numOrbiting + 0; // Number of sides for the center polygon
  
  
  float threshold = 10;  // This is an arbitrary value, you can adjust based on your needs
  boolean isBeat1 = fft.getBand(0) > threshold;
  boolean isBeat2 = fft.getBand(1) > threshold;
  float beatAlpha = beat.isKick() ? 255 : isBeat1 ? 64 : 32;
  
  float breathingMin = 0.7;
  float centerScale = breathingMin + (breathingMin/2) * (1 + sin(frameCount * 0.02)) / 2;
  
  if (isBeat1 || isBeat2 || beat.isKick()) {
    smokeRings.add(new SmokeRing(centerScale * 0.95, frameCount * centerRotationSpeed, smokeRings.size(), beatAlpha));
  }

  pushMatrix();
  translate(width / 2, height / 2);
  rotate(frameCount * centerRotationSpeed);
  drawPolygon(0, 0, centerSize * centerScale, centerSides);
  popMatrix();

  // X marks the spot
  //float markSize = height * 0.005;
  //stroke(255, 255 * cos(centerScale));
  //line(width / 2 - markSize, height / 2 - markSize, width / 2 + markSize, height / 2 + markSize);
  //line(width / 2 + markSize, height / 2 - markSize, width / 2 - markSize, height / 2 + markSize);

  for (int i = smokeRings.size() - 1; i >= 0; i--) {
    SmokeRing ring = smokeRings.get(i);
  
    pushMatrix();
    translate(width / 2, height / 2);
    //rotate(ring.framesAlive * centerRotationSpeed * ring.rotationSpeed);
    if (smokeRings.size() > 20) {
      if (starMode == false) {
        starMode = true;
        starModeDuration = frameCount;
      }
      //phaseDuration = starSides * (2/3);
      rotate(pow(ring.rotation, smokeRings.size() / 10));
      //int starSides = centerSides + round((frameCount - starModeDuration) / (6 * frameRate)) % 7;
      starSides = round((frameCount - starModeDuration) / (3 * frameRate)) % (numOrbiting);
      drawPolygon(0, 0, centerSize * ring.scale * 0.7, 3 + starSides);
    } else {
      starMode = false;
      starSides = 0;
      rotate(ring.rotation);
      drawPolygon(0, 0, centerSize * ring.scale, centerSides);
    }
    stroke(255, ring.alpha);
    popMatrix();
  
    ring.update();
  
    if (ring.isFaded()) {
      smokeRings.remove(i);
    }
  }
  
  stroke(255, 255);

  PVector[] orbitingCenters = new PVector[numOrbiting];
  int maxFFTIndex = fft.specSize() - 1;
  float bandSpacing = maxFFTIndex / (float) numOrbiting;

  // Orbiting Polygons and compute their centers
  for (int i = 0; i < numOrbiting; i++) {
      float angle = TWO_PI / numOrbiting * i + frameCount * PI / 300 - (PI / numOrbiting); 
      float distance = centerSize * 1.5;
      int orbitingSides = 3 + i; 
  
      float x = width / 2 + cos(angle) * distance;
      float y = height / 2 + sin(angle) * distance;
  
      // Store this polygon's center
      orbitingCenters[i] = new PVector(x, y);
  
      float orbitingScale = 1 + (fft.getBand(i * 10) * .05); 
      //float orbitingScale = 1 + (fft.getBand(int(i * bandSpacing)) * .05);
      //float orbitingScale = 1 + (fft.getBand(getLogarithmicBand(i, numOrbiting, 5000, in.sampleRate())) * .05);
      //if (orbitingScale > maxScaleEver) maxScaleEver = orbitingScale;
      //orbitingScale = orbitingScale > centerSize * centerScale - distance ? centerSize * centerScale - distance : orbitingScale;
      //orbitingScale = orbitingScale > 0.5 * centerSize * centerScale ? 2 : orbitingScale;
      float r_max = 2;
      //orbitingScale = (orbitingScale - 0) / (maxScaleEver - 0) * r_max;
      orbitingScale = orbitingScale > r_max ? r_max : orbitingScale;
      pushMatrix();
      translate(x, y);
      rotate(-frameCount * centerRotationSpeed * orbitingSides/numOrbiting);
      if (starMode && starSides == i) {
        strokeWeight(8);
      } else {
        strokeWeight(2);
      }
      drawPolygon(0, 0, orbitingSizes[i] * orbitingScale - centerScale, orbitingSides);
      popMatrix();
      strokeWeight(2);
  }

}

void drawPolygon(float x, float y, float size, int sides) {
  beginShape();
  for (int i = 0; i < sides; i++) {
    float angle = TWO_PI / sides * i;
    float sx = x + cos(angle) * size;
    float sy = y + sin(angle) * size;
    vertex(sx, sy);
  }
  endShape(CLOSE);
}
