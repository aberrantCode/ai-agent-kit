// ac-design-root.mjs — resolve the AC_DESIGN repository root.
//
// Order: AC_DESIGN_ROOT environment variable, then the workstation default
// C:\development\ac_design. Validated by the presence of the canonical
// design-system doc so a stale env var fails loudly instead of silently
// producing off-brand output.

import { existsSync } from 'node:fs';
import { join } from 'node:path';

const FALLBACK = 'C:\\development\\ac_design';

export function acDesignRoot() {
  const root = process.env.AC_DESIGN_ROOT || FALLBACK;
  const doc = join(root, 'docs', 'logo-design-system.md');
  if (!existsSync(doc)) {
    console.error(
      `ac-logo: AC_DESIGN repo not found at ${root} (missing docs/logo-design-system.md).`,
    );
    console.error('  set AC_DESIGN_ROOT to your ac_design checkout.');
    process.exit(1);
  }
  return root;
}
