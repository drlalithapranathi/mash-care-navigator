/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './launch.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        clinical: {
          blue: '#1e3a5f',
          'blue-light': '#2563eb',
        },
      },
    },
  },
  plugins: [],
}
