# AlphaScript Portfolio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Refresh the supplied AlphaScript portfolio and route contact requests to alphascript24@gmail.com.

**Architecture:** A static HTML/CSS/JavaScript site, with progressive enhancement for navigation and validation. Native HTTPS form submission uses FormSubmit with its spam verification enabled; the browser displays the provider response.

**Tech Stack:** HTML5, CSS, vanilla JavaScript. Python unittest + Playwright for development verification only.

**Spec:** `docs/superpowers/specs/2026-11-05-alphascript-portfolio-design.md`

## Global Constraints

- Maintain the dark, restrained blue identity selected by the user, and the supplied AlphaScript by GiaMMarK logo.
- Email destination: `alphascript24@gmail.com`.
- Preserve a static, framework-free site with no analytics or fabricated clients, results or finished projects.
- Use FormSubmit HTTPS POST, spam protection and explicit destination activation instructions; do not send actual emails during automated checks.
- Deliver editable sources and a hosting ZIP. No automatic deployment.
- The user delegated remaining choices and asked to proceed without further questions; execute inline with one final independent review.
- Use the existing isolated cloud checkout on branch `work`; do not create another worktree.

## Review Focus

- With JavaScript enabled, whitespace-only messages must not navigate to the provider or look submitted; without JavaScript retain the browser’s native required-field and email checks.
- Long text and a 320px viewport must preserve readable content and operable controls.
- Keyboard users must open and close the mobile navigation, regain focus and reach the form.
- Without JavaScript, the content, navigation and native email form must remain available.
- A provider page or an activation requirement must never be described as proof of email delivery.

---

### Task 1: Portfolio content and responsive navigation

**Files:** `alphascript/index.html`, `alphascript/style.css`, `alphascript/script.js`, `alphascript/privacy.html`, supplied PNG assets, `alphascript/tests/test_site.py`.

**Interfaces:** Header `.menu-toggle` controls `#main-nav`; sections `#home`, `#servizi`, `#profilo`, `#progetti`, `#contatti`. Form retains `#contact-form`, `name`, `email`, `project`, `message`, `#form-note`. Script loads with `defer`.

- [x] Write browser tests exercising keyboard navigation, focus restoration, usable first viewport and reduced-motion/no-JavaScript content.
- [x] Run against the supplied baseline and observe failures for missing accessibility or obstructing animation.
- [x] Implement the new layout, natural copy and navigation. Use real supplied assets; mark example projects as demonstrations. Remove blocking intro, fake metrics, cursor replacement and continuous effects.
- [x] Run the relevant tests; verify mobile and desktop screenshots, widths 320–1920, and local asset responses.
- [x] Commit the source and tests after green verification.

### Task 2: Email request flow

**Files:** Contact form in `alphascript/index.html`, handlers in `alphascript/script.js`, `alphascript/privacy.html`, `alphascript/tests/test_site.py`.

**Interfaces:** Form `POST https://formsubmit.co/alphascript24@gmail.com`, target `_blank`, `rel="noopener"`; names `name`, `email`, `project`, `message`, `_honey`, `_subject`, `_template`. Visible `#form-note` is a live status. Alternate mailto points to the same recipient.

- [x] Write a failing browser test: submit a real form with special characters, intercept only the provider transport and assert POST destination, reply email, project and message payload.
- [x] Add invalid/whitespace/honeypot cases that assert no outgoing submission, plus edit-preservation and mailto fallback tests.
- [x] Observe failures on the current placeholder/mailto implementation.
- [x] Implement native POST, honest status text, trimmed required-field validation and honeypot validation. Retain user values; do not set a false delivery success or disable CAPTCHA.
- [x] Update privacy to describe the actual provider and destination without inventing the owner’s legal identity.
- [x] Run all tests and commit after green verification.

### Task 3: Delivery and review

**Files:** `alphascript/README.md`, `alphascript/EMAIL_SETUP.md`, `alphascript/VALIDAZIONE.md`; `downloads/AlphaScript-Portfolio.zip`, screenshots and a standalone email setup guide.

**Interfaces:** ZIP root contains `index.html`, `privacy.html`, CSS/JS, logo/favicon and setup instructions; it must work on static hosting without a build step.

- [x] Document publishing, one-time FormSubmit activation and a subsequent real delivery check, distinguishing them from intercepted local testing.
- [x] Run the full browser suite and JavaScript syntax check; inspect desktop/mobile screenshots and create the ZIP without development tests or caches.
- [x] Extract ZIP and verify its actual local assets and navigation work; record exact test counts and limitations.
- [x] Commit deliverables, then request a fresh whole-change review against this plan and the spec, with a full diff package.
- [x] Fix substantive findings with a failing reproduction first; rerun the full suite and report evidence and any remaining activation/deployment requirements.
