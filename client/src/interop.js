import confetti from "https://cdn.skypack.dev/canvas-confetti";
let count = 200;
let defaults = {
  origin: { y: 0.7 },
};

function fire(particleRatio, opts) {
  confetti(
    Object.assign({}, defaults, opts, {
      particleCount: Math.floor(count * particleRatio),
    })
  );
}

export const onReady = ({ app, env }) => {
  // PORTS
  if (app.ports) {
    if (app.ports.launchConfetti) {
      app.ports.launchConfetti.subscribe(() => {
        fire(0.25, {
          spread: 26,
          startVelocity: 55,
        });

        fire(0.2, {
          spread: 60,
        });

        fire(0.35, {
          spread: 100,
          decay: 0.91,
          scalar: 0.8,
        });

        fire(0.1, {
          spread: 120,
          startVelocity: 25,
          decay: 0.92,
          scalar: 1.2,
        });

        fire(0.1, {
          spread: 120,
          startVelocity: 45,
        });
      });
    }
  }
};