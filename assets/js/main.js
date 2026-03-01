// Main JavaScript for AI History & Money Making Website

document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  initTimelineSlider();
  initAnimations();
  initAffiliateTracking();
});

// Mobile Navigation
function initNavigation() {
  const navToggle = document.createElement('button');
  navToggle.className = 'nav-toggle';
  navToggle.setAttribute('aria-label', 'Toggle navigation');
  navToggle.innerHTML = '<span></span><span></span><span></span>';
  
  const nav = document.querySelector('nav');
  if (nav) {
    const navMenu = nav.querySelector('ul');
    if (navMenu && window.innerWidth <= 768) {
      nav.insertBefore(navToggle, navMenu);
      navMenu.classList.add('nav-menu');
      
      navToggle.addEventListener('click', () => {
        navMenu.classList.toggle('active');
        navToggle.classList.toggle('active');
      });
    }
  }
}

// Timeline Interactive Slider
function initTimelineSlider() {
  const slider = document.getElementById('timelineRange');
  if (!slider) return;

  const timelineData = {
    1950: { era: '1950s', title: 'The Birth of AI', desc: 'Alan Turing publishes "Computing Machinery and Intelligence"' },
    1960: { era: '1960s', title: 'Early Neural Networks', desc: 'First perceptron demonstrations' },
    1970: { era: '1970s', title: 'AI Winter Begins', desc: 'Funding cuts slow progress' },
    1980: { era: '1980s', title: 'Expert Systems', desc: 'AI finds business applications' },
    1990: { era: '1990s', title: 'Machine Learning Emerges', desc: 'Statistical approaches gain traction' },
    2000: { era: '2000s', title: 'Deep Learning Revolution', desc: 'Neural networks achieve breakthrough results' },
    2010: { era: '2010s', title: 'AI Accessibility', desc: 'TensorFlow, GPUs make AI accessible' },
    2020: { era: '2020s', title: 'Generative AI', desc: 'GPT, DALL-E, and transformer models' }
  };

  const display = document.getElementById('timelineDisplay');
  
  slider.addEventListener('input', (e) => {
    const year = Math.round(e.target.value / 10) * 10;
    if (display && timelineData[year]) {
      display.innerHTML = `
        <h4>${timelineData[year].era}: ${timelineData[year].title}</h4>
        <p>${timelineData[year].desc}</p>
      `;
    }
  });
}

// Scroll Animations
function initAnimations() {
  const observerOptions = {
    root: null,
    rootMargin: '0px',
    threshold: 0.1
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('fade-in');
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);

  document.querySelectorAll('.era-card, .money-card, .pioneer-card, .case-study-card, .resource-card').forEach(el => {
    observer.observe(el);
  });
}

// Affiliate Link Tracking
function initAffiliateTracking() {
  document.querySelectorAll('a[href*="affiliate"], a[href*="amazon"], a[href*="Udemy"]').forEach(link => {
    link.addEventListener('click', (e) => {
      const url = link.href;
      console.log('Affiliate click:', url);
      
      if (typeof gtag !== 'undefined') {
        gtag('event', 'click', {
          event_category: 'affiliate',
          event_label: url
        });
      }
    });
  });
}

// Newsletter Signup (placeholder)
function showNewsletterSignup() {
  alert('Newsletter signup coming soon! In the meantime, explore our resources and follow us on social media.');
}

// Premium Features (placeholder)
function showPremiumTour() {
  alert('Premium features coming soon! Get early access by contributing to our content.');
}

// Consulting Info (placeholder)
function showConsultingInfo() {
  alert('AI History Consulting Services:\n\nWe offer research and analysis for:\n- Educational content\n- Business presentations\n- Academic research\n\nContact us for pricing.');
}

// Membership Info (placeholder)
function showMembershipInfo() {
  alert('Premium Membership coming soon!\n\nBenefits will include:\n- Exclusive AI research reports\n- Early access to new content\n- Direct Q&A with AI experts');
}

// Theme Toggle (if implemented)
function toggleTheme() {
  const html = document.documentElement;
  const current = html.getAttribute('data-theme');
  const next = current === 'dark' ? 'light' : 'dark';
  html.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
}

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function(e) {
    const href = this.getAttribute('href');
    if (href !== '#') {
      e.preventDefault();
      const target = document.querySelector(href);
      if (target) {
        target.scrollIntoView({ behavior: 'smooth' });
      }
    }
  });
});
