\name{tags}
\alias{a}
\alias{br}
\alias{code}
\alias{div}
\alias{em}
\alias{h1}
\alias{h2}
\alias{h3}
\alias{h4}
\alias{h5}
\alias{h6}
\alias{hr}
\alias{icon}
\alias{img}
\alias{includeCSS}
\alias{includeHTML}
\alias{includeMarkdown}
\alias{includeScript}
\alias{includeText}
\alias{is.singleton}
\alias{markdown}
\alias{p}
\alias{pre}
\alias{singleton}
\alias{span}
\alias{strong}
\alias{suppressDependencies}
\alias{tag}
\alias{tagAppendAttributes}
\alias{tagAppendChild}
\alias{tagAppendChildren}
\alias{tagGetAttribute}
\alias{tagHasAttribute}
\alias{tagSetChildren}
\alias{tags}
\alias{withMathJax}
\alias{withTags}
\title{Tags, included resources, and text helpers}
\description{Compatibility helpers for Shiny tag construction, included files, Markdown-like content, icons, and singleton metadata.}
\usage{
a(..., .noWS = NULL, .renderHook = NULL)

br(..., .noWS = NULL, .renderHook = NULL)

code(..., .noWS = NULL, .renderHook = NULL)

div(..., .noWS = NULL, .renderHook = NULL)

em(..., .noWS = NULL, .renderHook = NULL)

h1(..., .noWS = NULL, .renderHook = NULL)

h2(..., .noWS = NULL, .renderHook = NULL)

h3(..., .noWS = NULL, .renderHook = NULL)

h4(..., .noWS = NULL, .renderHook = NULL)

h5(..., .noWS = NULL, .renderHook = NULL)

h6(..., .noWS = NULL, .renderHook = NULL)

hr(..., .noWS = NULL, .renderHook = NULL)

icon(name, class = NULL, lib = 'font-awesome')

img(..., .noWS = NULL, .renderHook = NULL)

includeCSS(path, ...)

includeHTML(path)

includeMarkdown(path)

includeScript(path, ...)

includeText(path)

is.singleton(x)

markdown(md, extensions = TRUE, .noWS = NULL)

p(..., .noWS = NULL, .renderHook = NULL)

pre(..., .noWS = NULL, .renderHook = NULL)

singleton(x)

span(..., .noWS = NULL, .renderHook = NULL)

strong(..., .noWS = NULL, .renderHook = NULL)

suppressDependencies(x, ...)

tag(name, varArgs)

tagAppendAttributes(tag, ...)

tagAppendChild(tag, child)

tagAppendChildren(tag, ...)

tagGetAttribute(tag, attr)

tagHasAttribute(tag, attr)

tagSetChildren(tag, ...)

tags

withMathJax(ui)

withTags(code)
}
\arguments{
  \item{...}{Additional arguments passed to the constructor, renderer, handler, or compatibility helper.}
  \item{.noWS}{Whitespace compatibility option.}
  \item{.renderHook}{Compatibility or internal-style argument retained in the public call signature.}
  \item{name}{Name of an option, attribute, symbol, or resource.}
  \item{class}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{lib}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{path}{Path to a local file.}
  \item{x}{Object or expression.}
  \item{md}{Markdown text.}
  \item{extensions}{Markdown extension setting.}
  \item{varArgs}{Argument retained for Shiny source compatibility; its native effect is described in the details section.}
  \item{tag}{WinShiny tag object.}
  \item{child}{Child object to append.}
  \item{attr}{Attribute name.}
  \item{ui}{UI object or native UI description.}
  \item{code}{Expression evaluated with tag helpers in scope.}
}
\details{WinShiny converts a useful subset of tag-like objects to native WPF text and containers. Arbitrary HTML, CSS, JavaScript, and browser dependencies are not executed.}
\seealso{\code{README.md} in the installed package and \code{runExample()}.}
\keyword{programming}
