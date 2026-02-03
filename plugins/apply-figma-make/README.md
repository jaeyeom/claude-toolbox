# Figma Make Plugin

Apply designs exported from [Figma Make](https://www.figma.com/) to your website pages. Handles the conversion from React/motion.js to your framework's conventions (Astro, Next.js, etc.).

## Usage

```
/apply-figma-make ~/Downloads/Homepage-Design.zip
```

Or simply provide a Figma Make zip file and ask Claude to apply the design.

## What It Does

1. **Extracts** the Figma Make zip file
2. **Analyzes** the React component structure and animations
3. **Asks** about constraints (keep logo, remove badges, etc.)
4. **Converts** React/motion.js to CSS animations
5. **Optimizes** the generated code
6. **Verifies** the build passes

## Conversion Examples

| Figma Make (React) | Converts To |
|-------------------|-------------|
| `motion.div` with `animate` | CSS `@keyframes` |
| `motion.div` with `whileHover` | CSS `:hover` + `transition` |
| `[...Array(20)].map()` particles | CSS gradient backgrounds |
| Inline `style={{}}` | Tailwind classes |

## License

MIT
