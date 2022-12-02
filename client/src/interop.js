import confetti from "https://cdn.skypack.dev/canvas-confetti";

export const flags = ({ env }) => {
  return {
    settings: JSON.parse(localStorage.settings || null),
  };
};

let count = 200;
let defaults = {
  origin: { y: 0.7 },
};

function fire(particleRatio, opts) {
  confetti(
    Object.assign({}, defaults, opts, {
      particleCount: Math.floor(count * particleRatio),
      disableForReducedMotion: true,
    })
  );
}

export const onReady = ({ app, env }) => {
  // PORTS
  if (app.ports) {
    if (app.ports.saveToLocalStorage) {
      app.ports.saveToLocalStorage.subscribe(({ key, value }) => {
        localStorage[key] = JSON.stringify(value);
      });
    }

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

    if (app.ports.updateTheme) {
      let currentAuto = "light";
      let currentTheme = "auto";

      const updateAutoTheme = (event) => {
        currentAuto = event.matches ? "dark" : "light";
        if (currentTheme === "auto") {
          document.body.className = currentAuto;
        }
      };
      window
        .matchMedia("(prefers-color-scheme: dark)")
        .addEventListener("change", updateAutoTheme);
      
      updateAutoTheme(window.matchMedia("(prefers-color-scheme: dark)"));
      app.ports.updateTheme.subscribe((theme) => {
        switch (theme) {
          case "light":
            document.body.className = "light";
            break;
          case "dark":
            document.body.className = "dark";
            break;
          case "auto":
            document.body.className = currentAuto;
        }
        currentTheme = theme;
      });
    }
  }
};
