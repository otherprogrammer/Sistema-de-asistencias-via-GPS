/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Color principal de tu empresa
        primary: {
          50: '#f0f7ff',
          100: '#e0efff',
          200: '#b9ddff',
          300: '#7cc4ff',
          400: '#36a7ff',
          500: '#2D6EA4', // Tu color base
          600: '#2660a1',
          700: '#204d82',
          800: '#1f426c',
          900: '#1e3a5a',
        },
        // Colores de estado
        success: {
          50: '#f0fdf4',
          100: '#dcfce7',
          500: '#22c55e',
          600: '#16a34a',
          700: '#15803d',
        },
        danger: {
          50: '#fef2f2',
          100: '#fee2e2',
          500: '#ef4444',
          600: '#dc2626',
          700: '#b91c1c',
        },
        warning: {
          50: '#fffbeb',
          100: '#fef3c7',
          500: '#f59e0b',
          600: '#d97706',
          700: '#b45309',
        }
      },
      animation: {
        // Fade in/out
        'fade-in': 'fadeIn 0.2s ease-out forwards',
        'fade-out': 'fadeOut 0.15s ease-in forwards',

        // Slide animations
        'slide-in-bottom': 'slideInBottom 0.3s ease-out forwards',
        'slide-out-bottom': 'slideOutBottom 0.2s ease-in forwards',
        'slide-in-top': 'slideInTop 0.25s ease-out forwards',
        'slide-in-right': 'slideInRight 0.3s ease-out forwards',

        // Scale animations
        'scale-in': 'scaleIn 0.2s ease-out forwards',
        'scale-out': 'scaleOut 0.15s ease-in forwards',

        // Combined animations
        'modal-in': 'fadeIn 0.2s ease-out forwards, scaleIn 0.2s ease-out forwards',
        'modal-out': 'fadeOut 0.15s ease-in forwards, scaleOut 0.15s ease-in forwards',
      },
      keyframes: {
        // Fade animations
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        fadeOut: {
          '0%': { opacity: '1' },
          '100%': { opacity: '0' },
        },

        // Slide animations
        slideInBottom: {
          '0%': {
            transform: 'translateY(20px)',
            opacity: '0'
          },
          '100%': {
            transform: 'translateY(0)',
            opacity: '1'
          },
        },
        slideOutBottom: {
          '0%': {
            transform: 'translateY(0)',
            opacity: '1'
          },
          '100%': {
            transform: 'translateY(20px)',
            opacity: '0'
          },
        },
        slideInTop: {
          '0%': {
            transform: 'translateY(-20px)',
            opacity: '0'
          },
          '100%': {
            transform: 'translateY(0)',
            opacity: '1'
          },
        },
        slideInRight: {
          '0%': {
            transform: 'translateX(20px)',
            opacity: '0'
          },
          '100%': {
            transform: 'translateX(0)',
            opacity: '1'
          },
        },

        // Scale animations
        scaleIn: {
          '0%': {
            transform: 'scale(0.95)',
            opacity: '0'
          },
          '100%': {
            transform: 'scale(1)',
            opacity: '1'
          },
        },
        scaleOut: {
          '0%': {
            transform: 'scale(1)',
            opacity: '1'
          },
          '100%': {
            transform: 'scale(0.95)',
            opacity: '0'
          },
        },
      }
    },
  },
  plugins: [],
}
