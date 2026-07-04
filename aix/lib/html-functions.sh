# @(#) $Id: html-functions.sh,v 1.1 2015/07/27 12:01:15 ralph Exp $ 
# -------------------------------------------------------------------------
# vim:ts=8:sw=4:sts=4 -*- coding: utf-8 -*- Ralph Roth

function open_html {
    UNAMEA=$(uname -a)
    cat >$HTML_OUTFILE <<-EOF

	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
	<HTML> <HEAD>
	<META NAME="GENERATOR" CONTENT="Selfmade-$VERSION">
	<META NAME="AUTHOR" CONTENT="Ralph Roth, Gratien D'haese, Michael Meifert, Jeroen Kleen">
	<META NAME="CREATED" CONTENT="Ralph Roth, Gratien D'haese, Michael Meifert, Jeroen Kleen">
	<META NAME="CHANGED" CONTENT="`id;date` ">
	<META NAME="DESCRIPTION" CONTENT="Config to HTML (cfg2html for Linux)">
	<META NAME="subject" CONTENT="$VERSION on $RECHNER by $MAILTO and $MAILTORALPH">
	<style type="text/css">
	/* (c) 2001- 2015 by ROSE SWE, Ralph Roth - http://rose.rult.at
	* CSS for cfg2html.sh, 12.04.2001, initial creation
	*/

	Pre     {Font-Family: Courier-New, Courier;Font-Size: 10pt}
	BODY        {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif; FONT-SIZE: 12pt;}
	A       {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif}
	A:link      {text-decoration: none}
	A:visited   {text-decoration: none}
	A:hover     {text-decoration: underline}
	A:active    {color: red; text-decoration: none}

	H1      {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif;FONT-SIZE: 20pt}
	H2      {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif;FONT-SIZE: 14pt}
	H3      {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif;FONT-SIZE: 12pt}
	DIV, P, OL, UL, SPAN, TD
	{FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif;FONT-SIZE: 11pt}

	</style>

	<TITLE>${RECHNER} - System Documentation - $VERSION</TITLE>
	</HEAD><BODY>
	<BODY LINK="#0000ff" VLINK="#800080" BACKGROUND="cfg2html_back.jpg">
	<H1><CENTER><FONT COLOR=blue>
	<P><hr><B>$RECHNER - System Documentation</P></H1>
	<hr><FONT COLOR=blue><small>Created $DATEFULL with $PROGRAM $VERSION</font></center></B><P>
	$UNAMEA
	</small>

	<HR><H1>Contents</font></H1>

	EOF

    (line
      echo
      _banner $RECHNER
      #echo $RECHNER
      echo
    line) > $TEXT_OUTFILE
    _echo  "\n" >> $TEXT_OUTFILE
    _echo  "\n" > $TEXT_OUTFILE_TEMP
}

######################################################################
#  Increases the headling level
######################################################################

function inc_heading_level {
    HEADL=HEADL+1
    # echo -e "<UL>\n" >> $HTML_OUTFILE
    _echo "<UL type='square'>\n" >> $HTML_OUTFILE
}

######################################################################
#  Decreases the heading level
######################################################################

function dec_heading_level {
    HEADL=HEADL-1
    _echo "</UL>" >> $HTML_OUTFILE
}

######################################################################
#  Creates an own paragraph, $1 = heading
######################################################################

paragraph() {
    if [ "$HEADL" -eq 1 ] ; then
        _echo "<HR>" >> $HTML_OUTFILE_TEMP
    fi

    echo "<A NAME=\"$1\">" >> $HTML_OUTFILE_TEMP
    echo "<A HREF=\"#Inhalt-$1\"><H${HEADL}> $1 </H${HEADL}></A><P>" >> $HTML_OUTFILE_TEMP

    # commented to eliminate the need of the gif
    #echo "<IMG SRC="profbull.gif" WIDTH=14 HEIGHT=14>" >> $HTML_OUTFILE
    echo "<A NAME=\"Inhalt-$1\"></A><A HREF=\"#$1\">$1</A>" >> $HTML_OUTFILE
    _echo "\nCollecting: " $1 " .\c"
    echo "    $1 ---- " >> $TEXT_OUTFILE
}

function exec_command {

    # Start elpased time and show command if -T set
    SECONDS=0

    [[ "$CFG_TRACETIME" = "no" ]] && _echo ".\c"  # fails under Ubuntu/Linit Mint based systems!?

    _echo "\n---=[ $2 ]=----------------------------------------------------------------" | cut -c1-74 >> $TEXT_OUTFILE_TEMP
    echo "       - $2" >> $TEXT_OUTFILE
    ######the working horse##########
    TMP_EXEC_COMMAND_ERR=/tmp/exec_cmd.tmp.$$
    ## Modified 1/13/05 by marc.korte@oracle.com, Marc Korte, TEKsystems (150 -> 250)
    EXECRES=`eval $1 2> $TMP_EXEC_COMMAND_ERR | expand | cut -c 1-250`


    ########### test it ############
    # Gert.Leerdam@getronics.com
    # Convert illegal characters for HTML into escaped ones.
    #CONVSTR='
    #s/</\&lt;/g
    #s/>/\&gt;/g
    #s/\\/\&#92;/g
    #'
    #EXECRES=$(eval $1 2> $TMP_EXEC_COMMAND_ERR | expand | cut -c 1-150 | sed +"$CONVSTR")

    if [ -z "$EXECRES" ]
    then
        EXECRES="n/a or not configured"
    fi
    if [ -s $TMP_EXEC_COMMAND_ERR ]
    then
        echo "stderr output from \"$1\":" >> $ERROR_LOG
        cat $TMP_EXEC_COMMAND_ERR | sed 's/^/    /' >> $ERROR_LOG
    fi
    rm -f $TMP_EXEC_COMMAND_ERR

    if [ "$CFG_STINLINE" = "no" ]
    then
        ## screen tips like cfg2html 1.20 when dragging mouse over link?
        _echo "<A NAME=\"$2\"></A> <H${HEADL}><A HREF=\"#Inhalt-$2\" title=\"$1\"> $2 </A></H${HEADL}>" >>$HTML_OUTFILE_TEMP #orig screen tips by Ralph
    else
        ## or more netscape friendly inline?
        _echo "<A NAME=\"$2\"></A> <A HREF=\"#Inhalt-$2\"><H${HEADL}> $2 </H${HEADL}></A>" >>$HTML_OUTFILE_TEMP

        if [ "X$1" = "X$2" ]
            then    : #no need to duplicate, do nothing
        else
                echo "<h6>$1</h6>">>$HTML_OUTFILE_TEMP
        fi

    fi      # screen tips inline???

        ###  Put the result out in proportional font
    _echo "<PRE>$EXECRES</PRE>"  >>$HTML_OUTFILE_TEMP

    _echo "<LI><A NAME=\"Inhalt-$2\"></A><A HREF=\"#$2\" title=\"$1\">$2</A>" >> $HTML_OUTFILE
    echo "$EXECRES" >> $TEXT_OUTFILE_TEMP

    # Show each exec_command and elapsed secs
    if [[ "$CFG_TRACETIME" = "yes" ]]; then 
        SECS=$SECONDS
        Log "$SECS secs: $(echo $1 | cut -c-79)"
        echo "$SECS secs: $(echo $1 | cut -c-79)\n" >> $TEXT_OUTFILE_TEMP
        echo "<h6>$SECS secs: $(echo $1 | cut -c-79)</h6>" >> $HTML_OUTFILE_TEMP
    fi

}

################# adds a text to the output files, rar, 25.04.99 ##########

function AddText {

    echo "<p>$*</p>" >> $HTML_OUTFILE_TEMP
    _echo "$*\n" >> $TEXT_OUTFILE_TEMP
}

function close_html {

    echo "<hr>" >> $HTML_OUTFILE
    _echo "</P><P>\n<hr><FONT COLOR=blue>Created $DATEFULL with $PROGRAM $VERSION</font>" >> $HTML_OUTFILE_TEMP
    _echo "</P><P>\n<FONT COLOR=blue>Copyright and maintained by <A HREF="mailto:$MAILTORALPH?subject=$VERSION_">Ralph Roth, ROSE SWE, </A></P></font>" >> $HTML_OUTFILE_TEMP
    _echo "<hr><center> <A HREF="http://www.cfg2html.com">[ Download cfg2html from external home page ]</b></A></center></P><hr></BODY></HTML>\n" >> $HTML_OUTFILE_TEMP
    cat $HTML_OUTFILE_TEMP >>$HTML_OUTFILE
    cat $TEXT_OUTFILE_TEMP >> $TEXT_OUTFILE
    rm $HTML_OUTFILE_TEMP $TEXT_OUTFILE_TEMP
    _echo  "\n\nCreated "$DATEFULL" with " $PROGRAM $VERSION " \n" >> $TEXT_OUTFILE
    _echo  "(c) 1998- 2015 by ROSE SWE, Ralph Roth" >> $TEXT_OUTFILE
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
	<meta name="description" content="Config to HTML (cfg2html for AIX)">
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

