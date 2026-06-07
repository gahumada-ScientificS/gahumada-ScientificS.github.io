document.addEventListener('DOMContentLoaded', () => {

  // ============================================
  // 1. SCROLL FADE-IN (all pages)
  // ============================================
  const fadeObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        fadeObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });

  document.querySelectorAll('.fade-up').forEach(el => fadeObserver.observe(el));


  // ============================================
  // 2. COUNT-UP NUMBERS
  // ============================================
  function countUp(el) {
    const target = parseFloat(el.getAttribute('data-count'));
    const suffix = el.getAttribute('data-suffix') || '';
    const duration = 1800;
    const steps = 60;
    const increment = target / steps;
    let current = 0;
    let step = 0;
    const timer = setInterval(() => {
      step++;
      current = Math.min(increment * step, target);
      el.textContent = (Number.isInteger(target) ? Math.floor(current) : current.toFixed(0)) + suffix;
      if (step >= steps) clearInterval(timer);
    }, duration / steps);
  }

  const countObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        countUp(entry.target);
        countObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.5 });

  document.querySelectorAll('[data-count]').forEach(el => countObserver.observe(el));


  // ============================================
  // 3. TYPEWRITER EFFECT
  // ============================================
  const typewriterEl = document.getElementById('typewriter');
  if (typewriterEl) {
    const text = typewriterEl.getAttribute('data-text') || typewriterEl.textContent;
    typewriterEl.textContent = '';
    typewriterEl.style.borderRight = '2px solid #C9A84C';
    let i = 0;
    setTimeout(() => {
      const timer = setInterval(() => {
        typewriterEl.textContent += text.charAt(i);
        i++;
        if (i >= text.length) {
          clearInterval(timer);
          setTimeout(() => { typewriterEl.style.borderRight = 'none'; }, 800);
        }
      }, 75);
    }, 600);
  }


  // ============================================
  // 4. WORD CYCLING
  // ============================================
  const cycleEl = document.getElementById('cycling-words');
  if (cycleEl) {
    const words = [
      'Chemistry Experts.',
      'Quality Advisors.',
      'Innovation Partners.',
      'AI Pioneers.',
      'Your Scientific Team.',
      'Process Developers.',
      'CDMO Oversight Specialists.'
    ];
    let idx = 0;
    cycleEl.textContent = words[0];
    setInterval(() => {
      cycleEl.style.opacity = '0';
      cycleEl.style.transform = 'translateY(-8px)';
      setTimeout(() => {
        idx = (idx + 1) % words.length;
        cycleEl.textContent = words[idx];
        cycleEl.style.opacity = '1';
        cycleEl.style.transform = 'translateY(0)';
      }, 350);
    }, 3000);
  }


  // ============================================
  // 5. FLOATING PARTICLES
  // ============================================
  const canvas = document.getElementById('particle-canvas');
  if (canvas) {
    const ctx = canvas.getContext('2d');

    function resize() {
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    const particles = Array.from({ length: 70 }, () => ({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      size: Math.random() * 2.2 + 0.4,
      speedY: -(Math.random() * 0.45 + 0.15),
      speedX: (Math.random() - 0.5) * 0.25,
      opacity: Math.random() * 0.45 + 0.08,
      pulse: Math.random() * Math.PI * 2,
    }));

    function animateParticles() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      particles.forEach(p => {
        p.pulse += 0.02;
        const alpha = p.opacity + Math.sin(p.pulse) * 0.08;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(201, 168, 76, ${Math.max(0, alpha)})`;
        ctx.fill();
        p.y += p.speedY;
        p.x += p.speedX;
        if (p.y < -5) { p.y = canvas.height + 5; p.x = Math.random() * canvas.width; }
        if (p.x < -5) p.x = canvas.width + 5;
        if (p.x > canvas.width + 5) p.x = -5;
      });
      requestAnimationFrame(animateParticles);
    }
    animateParticles();
  }


  // ============================================
  // 6. SVG MAP PATH DRAW
  // ============================================
  const mapPaths = document.querySelectorAll('.map-continent');
  if (mapPaths.length) {
    const mapObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          mapPaths.forEach((path, i) => {
            setTimeout(() => path.classList.add('draw'), i * 120);
          });
          mapObserver.disconnect();
        }
      });
    }, { threshold: 0.2 });
    mapObserver.observe(mapPaths[0].closest('svg') || mapPaths[0]);
  }


  // ============================================
  // 7. GOLD SHIMMER ON HOVER (nav logo)
  // ============================================
  const navLogo = document.querySelector('.nav-logo');
  if (navLogo) {
    navLogo.addEventListener('mouseenter', () => {
      navLogo.classList.add('shimmer-active');
    });
    navLogo.addEventListener('mouseleave', () => {
      setTimeout(() => navLogo.classList.remove('shimmer-active'), 600);
    });
  }

});
