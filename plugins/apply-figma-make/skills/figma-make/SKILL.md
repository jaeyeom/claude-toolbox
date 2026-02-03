---
name: apply-figma-make
description: Apply Figma Make exported designs to website pages. Converts React/motion code to framework-appropriate code (Astro, Next.js, etc.) with CSS animations.
argument-hint: "<path-to-zip> [target-page]"
---

# Figma Make Design Application

Apply designs exported from Figma Make to your website pages. Handles the conversion from React/motion.js to your framework's conventions.

## When to Use

This skill activates when:
- User provides a Figma Make zip file
- User says "apply this design", "use this Figma export"
- User wants to implement a design from a `.zip` containing React components

## Workflow

### Phase 1: Extract and Analyze

1. **Extract the zip file** to a temporary directory
   ```bash
   unzip -o "<path-to-zip>" -d "$TMPDIR/figma-design"
   ```
   Note: Use `$TMPDIR` or any suitable temp directory. Claude will determine the appropriate location at runtime.

2. **Identify key files**
   - Main component: `src/app/App.tsx` or similar
   - Guidelines: `guidelines/Guidelines.md` (if present)
   - Theme/styles: `src/styles/theme.css`, `tailwind.css`

3. **Read the design file** to understand:
   - Layout structure (sections, containers)
   - Animation patterns (motion.js usage)
   - Color scheme and gradients
   - Component hierarchy

### Phase 2: Gather User Constraints

**IMPORTANT**: Before applying, ask the user about constraints:

```
Task(subagent_type="general-purpose", prompt="
Ask the user using AskUserQuestion:
1. Which page(s) should receive this design?
2. Are there elements to KEEP unchanged? (e.g., existing logo, header, footer)
3. Are there elements to REMOVE from the design? (e.g., badges, specific sections)
4. Any other customizations needed?
")
```

Common constraints:
- **Keep existing logo** - Don't replace with design's placeholder logo
- **Remove marketing badges** - "AI-powered", "New", etc.
- **Preserve navigation structure** - Keep existing routes/links

### Phase 3: Convert and Apply

**Conversion Rules for Astro/Static Sites:**

| Figma Make (React) | Convert To |
|-------------------|------------|
| `motion.div` with `animate` | CSS `@keyframes` animation |
| `motion.div` with `whileHover` | CSS `:hover` with `transition` |
| `motion.div` with `whileInView` | CSS animation (plays on load) |
| `useState`/`useEffect` for scroll | CSS or remove if decorative |
| `[...Array(N)].map()` particles | CSS gradients or fewer elements |
| Inline `style={{}}` | Tailwind classes or `<style>` |

**Delegate to executor:**
```
Task(
  subagent_type="oh-my-claudecode:executor",
  model="sonnet",
  prompt="Apply the Figma Make design to [target page].

  DESIGN SOURCE: [extracted temp directory]/src/app/App.tsx
  TARGET FILE: [path to target page]

  CONSTRAINTS:
  - [User's constraints from Phase 2]

  CONVERSION REQUIREMENTS:
  - Convert all motion.js animations to CSS @keyframes
  - Convert React state-based animations to CSS transitions
  - Replace particle arrays with CSS gradient backgrounds
  - Use Tailwind classes where possible
  - Add custom CSS in <style> tags for complex animations

  PRESERVE:
  - Existing imports and layout structure
  - Logo references (use existing logo paths)
  - Navigation links and routes

  OUTPUT: Modified page file with design applied"
)
```

### Phase 4: Optimize

After initial application, simplify the code:

```
Task(
  subagent_type="code-simplifier:code-simplifier",
  prompt="Optimize the recently modified files:
  - Remove Figma Make boilerplate
  - Consolidate duplicate Tailwind classes into CSS utilities
  - Convert repeated HTML into data-driven loops
  - Simplify complex animations
  - Remove unnecessary wrapper divs

  Keep visual design intact - only simplify implementation."
)
```

### Phase 5: Verify

1. **Build the project**
   ```bash
   npm run build
   ```

2. **Check for errors** - Fix any build/type errors

3. **Report changes** - List modified files and key changes

## Example Usage

```
User: Apply this design to homepage
      /Users/me/Downloads/Homepage-Design.zip

Claude:
1. Extracts zip to a temporary directory
2. Reads App.tsx to understand design
3. Asks: "Any elements to keep or remove?"
4. User: "Keep our logo, remove the AI badge"
5. Applies design with constraints
6. Optimizes generated code
7. Verifies build passes
8. Reports: "Homepage updated with new hero, cards, CTA sections"
```

## Tips

- **Check viewBox on SVGs** - Figma exports may have different dimensions
- **Watch for hardcoded colors** - Replace with your theme colors
- **Gradient text needs `bg-clip-text`** - Common pattern in Figma designs
- **Floating elements** - Often better as CSS pseudo-elements than DOM nodes

## Common Issues

| Issue | Solution |
|-------|----------|
| Logo appears wrong size | Check SVG viewBox matches your existing logo |
| Animations janky | Simplify or use `will-change` CSS property |
| Too many DOM elements | Replace particle arrays with CSS gradients |
| Colors don't match | Map Figma colors to your Tailwind theme |
