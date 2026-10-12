// Variables de estado del juego
int gameState = 0; // 0: Jugando, 1: Éxito, 2: Choque

// Variables cinemáticas de la nave
float x, y;      
float vx, vy;    
float angle = 0; 

// Constantes físicas
float gravity = 0.005;
float thrust = 0.01;

// Variables de control de teclas
boolean leftPressed = false;
boolean rightPressed = false;
boolean thrustPressed = false;

// Constantes de terreno, plataforma y colisión
float groundY = 550;
float padX = 350;
float padWidth = 100;
float maxSafeVelocity = 2.0;

// Arreglos para el fondo de estrellas
float[] starsX = new float[100];
float[] starsY = new float[100];
PImage texturaTierra;

void setup() {
  size(800, 600);
  
  for (int i = 0; i < 100; i++) {
    starsX[i] = random(width);
    starsY[i] = random(groundY); // Solo se dibujan por encima del suelo
  }
  
  texturaTierra = loadImage("Textura_tierra.jpg");
  reiniciarJuego();
  gameState = 3;
}

void draw() {
  background(0); 
    
    // Dibujo del espacio estrellado
    stroke(255);
    strokeWeight(2);
    for (int i = 0; i < 100; i++) {
      point(starsX[i], starsY[i]);
    }
    strokeWeight(1);
    if (gameState == 0) {
      // 1. Lógica de física y controles
      if (leftPressed) angle -= 0.05;
      if (rightPressed) angle += 0.05;
      if (thrustPressed) {
        vx += sin(angle) * thrust;
        vy -= cos(angle) * thrust;
      }
      // 1. Lógica de física y controles
      vy += gravity;
      x += vx;
      y += vy;
      
      // 2. Dibujo de la nave (traslación y rotación)
      pushMatrix();
      translate(x, y);
      rotate(angle);
      if (thrustPressed) {
        fill(255, 150, 0); // Color naranja para el fuego
        noStroke();
        triangle(-6, 10, 6, 10, random(-4, 4), random(20, 30));
      }
      
      stroke(255);
      fill(180);
      rect(-10, -5, 20, 15); // Cuerpo principal
      fill(100, 200, 255);
      arc(0, -5, 16, 16, PI, TWO_PI); // Cabina superior
      strokeWeight(2);
      line(-10, 10, -15, 15); // Pata izquierda
      line(10, 10, 15, 15); // Pata derecha
      strokeWeight(1);
     
      popMatrix();
      
      // 3. Dibujo del terreno y plataforma
      if (texturaTierra != null) {
        image(texturaTierra, 0, groundY, width, height - groundY);
      } else {
        fill(50); // Color base del terreno
        noStroke();
        rect(0, groundY, width, height - groundY); 
      }
      stroke(0, 255, 0); // Plataforma en verde
      strokeWeight(4);
      line(padX, groundY, padX + padWidth, groundY); 
      strokeWeight(1);
      noStroke();
      
      // 4. Detección de colisiones
      if (y + 15 >= groundY) { // +10 por la base de la nave
        y = groundY - 15; // Corrige la posición para que no traspase el suelo
        
        boolean onPad = x >= padX && x <= padX + padWidth;
        boolean safeSpeed = vy < maxSafeVelocity;
        boolean safeAngle = cos(angle) > cos(radians(30)); // Tolerancia estricta de +/- 30 grados
        
        if (onPad && safeSpeed && safeAngle) {
          gameState = 1; // Éxito
        } else {
          gameState = 2; // Choque
        }
      }
      // 5. Interfaz de telemetría (HUD)
      fill(255);
      textSize(16);
      textAlign(LEFT);
      text("ÁNGULO: " + nf(degrees(angle), 0, 2) + "°", 30, 40);
      text("Angulo maximo permitido = +/- 30°", 30, 65);
      text("VELOCIDAD: " + nf(vy*10, 0, 2), 30, 90);
      text("Velocidad máxima permitida = 20", 30, 115);
      
      textAlign(RIGHT);
      float altitudReal = max(0, groundY - (y + 15));
      text("ALTITUD: " + nf(altitudReal, 0, 2), width - 30, 40);
      textAlign(LEFT); // Restaura la alineación para las pantallas de reinicio
      
      
      
      
  } else if (gameState == 1) {
    textAlign(CENTER, CENTER);
    textSize(32);
    text("Aterrizaje exitoso. Presione 'R' para reiniciar", width/2, height/2);
  } else if (gameState == 2) {
    textAlign(CENTER, CENTER);
    textSize(32);
    text("Nave destruida. Presione 'R' para reiniciar", width/2, height/2);
  } else if (gameState == 3) {
    textAlign(CENTER, CENTER);
    textSize(32);
    text("Presione 'S' para comenzar el simulador", width/2, height/2);
  }
}

void reiniciarJuego() {
  x = random(50, width - 50);
  y = 50;
  vx = 0;
  vy = 0;
  angle = HALF_PI;
  padX = random(0, width - padWidth); // Calcula nueva posición para la plataforma
  gameState = 0;
}

void keyPressed() {
  if (gameState == 3 && (key == 's' || key == 'S')) {
    gameState = 0; // Inicia el juego
  }
  if (key == 'r' || key == 'R') {
    if (gameState == 1 || gameState == 2) {
      reiniciarJuego();
    }
  }
  if (keyCode == LEFT || keyCode == 'a' || keyCode == 'A' ) leftPressed = true;
  if (keyCode == RIGHT || keyCode == 'd' || keyCode == 'D') rightPressed = true;
  if (key == ' ' || keyCode == UP || keyCode == 'w' || keyCode == 'W') thrustPressed = true;
}

void keyReleased() {
  if (keyCode == LEFT || keyCode == 'a' || keyCode == 'A' ) leftPressed = false;
  if (keyCode == RIGHT || keyCode == 'd' || keyCode == 'D') rightPressed = false;
  if (key == ' ' || keyCode == UP || keyCode == 'w' || keyCode == 'W') thrustPressed = false;
}
