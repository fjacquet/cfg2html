
# shellcheck disable=SC2034,SC2148
# (note - shellcheck directive needs to be at the very top to be effective over the whole file)
# SC2034 - MACOS_VERSION is used across files sourced together, not visible to a single-file scan
# SC2148 - dot-sourced by the wrapper, never executed directly, no shebang by design
# cfg2html - macOS (Darwin) specific functions

function identify_macos_version {
    MACOS_VERSION="$(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
}

function generate_pretty_html {
    # Produces an ADDITIONAL, modern-CSS report alongside the classic
    # ${HTML_OUTFILE}/${TEXT_OUTFILE} -- purely additive post-processing of
    # the already-finished classic HTML file. Does not touch open_html,
    # paragraph, exec_command, close_html, or the classic outputs in any
    # way, so nothing about the existing report format changes.
    #
    # Splits the classic file at its "<HR><H1>Contents</font></H1>" line
    # (a fixed, unique marker written verbatim by open_html) and keeps
    # everything after it -- the real table of contents, every collected
    # section, and close_html's footer -- completely unmodified, prefixed
    # with a clean HTML5 head/masthead instead of the original's deprecated
    # HTML 3.2 doctype, inline <FONT>/<CENTER> tags, duplicate <BODY> tag,
    # and dead cfg2html_back.jpg background reference.
    PRETTY_HTML_OUTFILE="${OUTDIR}/${BASEFILE}.pretty.html"
    MARKER_LINE=$(grep -n '<HR><H1>Contents</font></H1>' "${HTML_OUTFILE}" | head -1 | cut -d: -f1)

    if [ -z "${MARKER_LINE}" ]; then
        Log "generate_pretty_html: Contents marker not found in ${HTML_OUTFILE}, skipping pretty HTML output"
        return 0
    fi

    cat > "${PRETTY_HTML_OUTFILE}" <<-EOF
	<!DOCTYPE html>
	<html lang="en">
	<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="generator" content="Selfmade-${VERSION}">
	<meta name="description" content="Config to HTML (cfg2html for macOS)">
	<title>${RECHNER} - System Documentation - ${VERSION}</title>
	<style>
	:root {
	  --bg: #fafafa;
	  --surface: #f1f3f5;
	  --text: #1c2530;
	  --text-muted: #5b6672;
	  --accent: #2e6e8e;
	  --border: #d7dce1;
	}
	@media (prefers-color-scheme: dark) {
	  :root {
	    --bg: #12161c;
	    --surface: #1b212a;
	    --text: #dce3ea;
	    --text-muted: #8b95a1;
	    --accent: #6fb3d2;
	    --border: #2a323c;
	  }
	}
	* { box-sizing: border-box; }
	body {
	  max-width: 960px;
	  margin: 0 auto;
	  padding: 2rem 1.25rem 4rem;
	  background: var(--bg);
	  color: var(--text);
	  font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
	  font-size: 15px;
	  line-height: 1.5;
	}
	a { color: var(--accent); text-decoration: none; }
	a:hover { text-decoration: underline; }
	a:active { color: var(--accent); }
	h1, h2, h3 {
	  font-family: ui-monospace, SFMono-Regular, "Cascadia Code", Consolas, "Liberation Mono", monospace;
	  font-weight: 600;
	  text-wrap: balance;
	  color: var(--text);
	}
	h1 { font-size: 1.5rem; margin: 2.5rem 0 1rem; padding-bottom: 0.5rem; border-bottom: 2px solid var(--accent); }
	h2 { font-size: 1.05rem; margin: 1.75rem 0 0.5rem; color: var(--accent); }
	h3 { font-size: 0.95rem; margin: 1.25rem 0 0.5rem; }
	h6 {
	  font-family: ui-monospace, SFMono-Regular, "Cascadia Code", Consolas, "Liberation Mono", monospace;
	  font-size: 0.8rem;
	  color: var(--text-muted);
	  font-weight: 400;
	  margin: 0 0 0.35rem;
	}
	p, div { font-size: 0.95rem; }
	ul { padding-left: 1.25rem; list-style-type: square; }
	li { margin: 0.15rem 0; }
	pre {
	  font-family: ui-monospace, SFMono-Regular, "Cascadia Code", Consolas, "Liberation Mono", monospace;
	  font-size: 0.82rem;
	  background: var(--surface);
	  border: 1px solid var(--border);
	  border-radius: 4px;
	  padding: 0.75rem 1rem;
	  overflow-x: auto;
	  white-space: pre;
	  margin: 0 0 1.25rem;
	}
	hr { border: none; border-top: 1px solid var(--border); margin: 1.5rem 0; }
	.masthead { padding-bottom: 1.5rem; margin-bottom: 1.5rem; border-bottom: 2px solid var(--accent); }
	.masthead h1 { border-bottom: none; margin: 0 0 0.35rem; font-size: 1.8rem; }
	.masthead .meta { color: var(--text-muted); font-size: 0.85rem; font-family: ui-monospace, SFMono-Regular, "Cascadia Code", Consolas, "Liberation Mono", monospace; }
	</style>
	</head>
	<body>
	<div class="masthead">
	<h1>${RECHNER} - System Documentation</h1>
	<div class="meta">Created ${DATEFULL} by ${PROGRAM} ${VERSION}<br>${UNAMEA}</div>
	</div>
	<h1>Contents</h1>
	EOF

    tail -n +$((MARKER_LINE + 1)) "${HTML_OUTFILE}" >> "${PRETTY_HTML_OUTFILE}"
}
