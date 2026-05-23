// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  place(
    top,
    float: true,
    scope: "parent",
    clearance: 4mm,
    block(below: 1em, width: 100%)[

      #if title != none {
        align(center, block(inset: 2em)[
          #set par(leading: heading-line-height) if heading-line-height != none
          #set text(font: heading-family) if heading-family != none
          #set text(weight: heading-weight)
          #set text(style: heading-style) if heading-style != "normal"
          #set text(fill: heading-color) if heading-color != black

          #text(size: title-size)[#title #if thanks != none {
            footnote(thanks, numbering: "*")
            counter(footnote).update(n => n - 1)
          }]
          #(if subtitle != none {
            parbreak()
            text(size: subtitle-size)[#subtitle]
          })
        ])
      }

      #if authors != none and authors != () {
        let count = authors.len()
        let ncols = calc.min(count, 3)
        grid(
          columns: (1fr,) * ncols,
          row-gutter: 1.5em,
          ..authors.map(author =>
              align(center)[
                #author.name \
                #author.affiliation \
                #author.email
              ]
          )
        )
      }

      #if date != none {
        align(center)[#block(inset: 1em)[
          #date
        ]]
      }

      #if abstract != none {
        block(inset: 2em)[
        #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
        ]
      }
    ]
  )

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Research Process for Music Psychologists],
  subtitle: [R version],
  author: "DY",
  date: "2026-05-24",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Preface]
<preface>
This is an R adaptation of the quantitative research/statistics content from a subject called Research Process for Music Psychologists (MUSI90252). The subject is an introduction to research methods for new Masters and PhD students in music psychology and music science at the University of Melbourne.

#strong[Some context, and why this book exists]

The subject's statistics material was originally written for #link("https://www.jamovi.org/")[Jamovi], given its ease of use and impressive functionality. The reason why we (the original subject coordinator and I) preferenced Jamovi in the first instance is because many of our students do not come from psychological science, statistics or research backgrounds, so statistical analysis is often an entirely new frontier for them. Jamovi provides a #emph[free] point-and-click interface that will be familiar to users of SPSS and other platforms who may be used to a point-and-click approach. I actually think this is a great thing, and I believe one of Jamovi's greatest strengths is how easy it is to use.

However, I have also strongly encouraged any music psychology students doing quantitatively-oriented research to consider learning R in the long term. R is therefore also offered as an option for this subject, and this book is meant to serve as the R-specific version of the subject material.

By and large the content is a very faithful reproduction of the subject's original Jamovi-oriented content, with the following exceptions:

- Some additional commentary has been added for R-specific material, such as information on certain functions.
- Some embedded content in the Canvas version is not available here (mainly Jamovi-specific content, and Readings Online content).
- Some content has been re-organised because of how R outputs things compared to Jamovi.
- The first chapter is a very (#emph[very]) brief overview of how to use core R and #NormalTok("tidyverse"); functions.

Also like the Jamovi version, #strong[Parts I and II] of this book form the relevant assessable content (Weeks 5-10), while Part III is an extension of the material beyond the core subject. It is also provided here though for interested readers.

Where possible, the subject content has been written to achieve #strong[parity with Jamovi] first and foremost, to reduce discrepancies and friction between the two versions of the subject material. The material in this book has been designed to align with what Jamovi provides as closely as possible, in terms of both functionality and output. As an avid R user myself though, I am aware that this means that there will be things that R can do that we do not closely discuss, or there may be things that Jamovi does that are somewhat different to what other programs (or R packages) may do or recommend. R can and will do so much more than what is presented in this book, and I strongly encourage interested students to seek out this content separately.

#strong[Information boxes]

Throughout the book you will see a number of #strong[boxes], highlighted with different colours and labelled with different icons and labels (one of the major upgrades to this book as a result of moving to Quarto). Some of them will be hidden by default, and can be expanded by clicking on them. Here is what the various boxes mean:

#block[
#callout(
body: 
[
These blue info boxes will contain additional supplementary information about some of the concepts discussed in the subject/book.

]
, 
title: 
[
Information boxes
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Throughout the book there are various #emph[R Notes], which provide additional tips, clarifications or information about functions or procedures specific to R. You will find them in these cute green boxes.

]
, 
title: 
[
R Notes
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
These warning boxes indicate topics, concepts or procedures that are important to know/remember, or highlight things to avoid.

]
, 
title: 
[
Warning boxes
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
#strong[About this book]

Up until 22nd May 2026, this book was written using #link("https://bookdown.org/")[bookdown]. I changed the book to #link("https://quarto.org/")[Quarto], partly because of the additional functinality built in to Quarto and partly because I really like how Quarto books look. It has come at the small cost of one or two features - such as the ability to easily split chapters into multiple pages - but overall makes for (imo) a much nicer reading experience.

The bookdown version is available on a separate branch on my GitHub.

Several elements in this new version of the book will be updated as time goes on. This first render in Quarto may be a bit rough around the edges while I work through these.

#part[Part I: Introduction]
= A very brief introduction to R
<intro-to-R>
This chapter is not meant to be an exhaustive be-all end-all to how to use R. It will only go through enough to complete RPMP's content. It will, however, introduce a couple of things that I think make for good starting habits using R - which is never a bad thing!

Naturally, if you are reading this version of the RPMP material and are interested in using R, you will need to download #link("https://www.r-project.org/")[R] and #link("https://posit.co/download/rstudio-desktop/")[RStudio].

In general, I am a huge proponent of the 'tidy' workflow of data analysis. While it was originally designed for data science in mind, I think it's a valuable model for psychological science as well:

!(https:\/\/d33wubrfki0l68.cloudfront.net/e5bf2a8f4c787a12facbc0b4191fc82bd192f4c5/4e5d2/diagrams/data-science-model.png)

The original subject was written with this workflow broadly in mind, although it wasn't intended to follow this closely (only to bring awareness to the general idea of modelling). For a far more comprehensive and rigorous overview of how to program in R, there is no better guide than #emph[R 4 Data Science] (R4DS) by Hadley Wickham: #link("https://r4ds.had.co.nz/").

== Navigating RStudio
<R-Studio>
=== The four panes
<the-four-panes>
When you open RStudio, you will see four main panes on your screen. They are as follows.

#align(center)[#box(image("img/RStudio_Screen1.png"))]
The first pane, and probably the one you will spend the most time in, is the #strong[source pane]. This is where you can write and edit your scripts, which are your files that contain R code. Generally, you will be working with either .R files (which contain code only) or .rmd files (which are more akin to traditional documents with chunks that execute code).

There are some main elements to the source pane that are useful to know, which have been numbered above:

+ Each file you are working on will have its own tab. As you can see here, I currently have three files (including the source document for this very chapter!).
+ Any lines of text with a hash (\#) in front of them are #emph[comments], which enable you to write text without executing code. These are super useful for annotating your code so that others can understand what your code does.
+ This is a line of code. As you can see, RStudio will colour different elements of the code in different colours.
+ This button will run any code that you have selected. To use it, highlight the code you want to run and click this button.

#align(center)[#box(image("img/RStudio_Screen2.png"))]
In the top right you will have the #strong[environments] pane. If you create variables or load in data, you will be able to see them here.

#align(center)[#box(image("img/RStudio_Screen3.png"))]
In the bottom left you will see the #strong[console]. This is where all R code is actually executed, and where all output is printed. When you run code from the source pane (e.g.~from a script), you will see the code being run down in the console. You can also execute code directly in the console if needed.

#align(center)[#box(image("img/RStudio_Screen4.png"))]
Finally, in the bottom right you will have what is usually called the #strong[output] pane. You can see that there are multiple tabs in this pane as well. From left to right, the main ones you need are:

- Files: A file explorer that lets you see all your files.
- Plots: Any graphics (e.g.~plots) will be shown in this tab.
- Packages: This lets you see what #emph[packages] are installed. More on this in a few pages!
- Help: This pane lets you search for help pages on functions.

=== Projects
<projects>
One of the great features of R is that we can easily create #strong[projects] within RStudio. Projects allow us to contain everything related to a single project/line of work within one main folder.

All of the R-related files that are provided in this course come in .zip files. Once you unzip these files, you may see something like this:

#Skylighting(([#NormalTok("|-RPMP");],
[#NormalTok("|---rpmp_week1.Rmd");],
[#NormalTok("|---w1_dataset.csv");],
[#NormalTok("|---RPMP.rproj");],));
Here, we have one data file (.csv), one file of code (.Rmd) and one .rproj file. Always #strong[open the .rproj file] to ensure that everything is set up correctly. Once you have done that, you will see RStudio switch over to this project.

We won't get #emph[too] deep into project-oriented workflows for RPMP. However, there are several benefits to working within projects in RStudio, which we will expand on in the coming pages. One benefit that we can discuss now though is that projects simply encourage effective and easy file management: by containing everything within the one folder, you can organise all your files relevant to that project within the one group. It might be useful, for example, to create one Project for each study in your thesis (if your thesis is quantitative and you plan on using R).

Switching between projects is also easy by using the little icon at the very top right of your screen (above the environment pane):

#align(center)[#box(image("img/RStudio_Screen5.png"))]
== Basic syntax
<R-syntax>
=== Operators
<operators>
We can do basic maths in R using the following symbols:

- Addition: #NormalTok("+");

- Subtraction: #NormalTok("-");

- Multiplication: #NormalTok("*");

- Division: #NormalTok("/");

- Exponentiation: #NormalTok("^");

#block[
#Skylighting(([#CommentTok("# Addition and subtraction");],
[#DecValTok("5");#NormalTok(" ");#SpecialCharTok("+");#NormalTok(" ");#DecValTok("2");],));
#block[
#Skylighting(([#NormalTok("[1] 7");],));
]
#Skylighting(([#DecValTok("6");#NormalTok(" ");#SpecialCharTok("-");#NormalTok(" ");#DecValTok("3");],));
#block[
#Skylighting(([#NormalTok("[1] 3");],));
]
]
#block[
#Skylighting(([#CommentTok("# Multiplication and division");],
[#DecValTok("2");#NormalTok(" ");#SpecialCharTok("*");#NormalTok(" ");#DecValTok("5");],));
#block[
#Skylighting(([#NormalTok("[1] 10");],));
]
#Skylighting(([#DecValTok("24");#SpecialCharTok("/");#DecValTok("6");],));
#block[
#Skylighting(([#NormalTok("[1] 4");],));
]
]
R will recognise brackets and perform calculations appropriately, following BEDMAS (or PEMDAS). As you normally would with a written equation, R will perform calculations left to right.

#block[
#Skylighting(([#NormalTok("(");#DecValTok("6");#NormalTok(" ");#SpecialCharTok("+");#NormalTok(" ");#DecValTok("2");#NormalTok(") ");#SpecialCharTok("*");#NormalTok(" ");#DecValTok("3");#SpecialCharTok("/");#DecValTok("4");],));
#block[
#Skylighting(([#NormalTok("[1] 6");],));
]
]
=== Assignment and naming
<assignment-and-naming>
When you type something in R, you almost always have the option of #emph[assigning] that value to an object/variable to give it a name. In R, assigning values/strings etc. to objects is slightly different to other programming languages. Instead of using equals signs, we use a left arrow #NormalTok("<-"); for assignment. For example:

#block[
#Skylighting(([#CommentTok("# Use this");],
[#NormalTok("x ");#OtherTok("<-");#NormalTok(" ");#DecValTok("5");],
[],
[#CommentTok("# This works but isn't preferred ");],
[#NormalTok("x ");#OtherTok("=");#NormalTok(" ");#DecValTok("5");],));
]
When it comes to naming variables and the like, the easiest/most readable way for most people is to separate words using an underscore. e.g.

#block[
#Skylighting(([#CommentTok("# this is preferred");],
[#NormalTok("variable_name");],
[],
[#CommentTok("# this is also very common");],
[#NormalTok("variable.name");],
[],
[#CommentTok("# sentence case is also sometimes used");],
[#NormalTok("VariableName");],
[],
[#CommentTok("# no spaces are allowed");],
[#NormalTok("variable name ");#CommentTok("# This will give you an error, as R will think this is two separate variables");],
[],
[#CommentTok("# some heathens use camel case");],
[#NormalTok("variableName");],));
]
To view what has been assigned to an object, you can simply write the variable name:

#block[
#Skylighting(([#CommentTok("# This is the variable we named earlier");],
[#NormalTok("x");],));
#block[
#Skylighting(([#NormalTok("[1] 5");],));
]
]
In general, it is good practice to use variable names that are #strong[clear] but #strong[concise]. In other words, avoid naming your variables something like #NormalTok("x1");, #NormalTok("x2"); etc. Instead, use the name of the measure/thing the data represents directly, e.g.~#NormalTok("scale_total");.

=== Variable types
<variable-types>
Like many programming languages, R works by manipulating different types of variables. Knowing how to work with these different variables is fairly essential to using R, so here is a brief overview.

First, we have our most basic classes of variables. The first is #strong[numeric], which is as it says on the tin (i.e.~it stores numbers):

#block[
#Skylighting(([#NormalTok("var_a ");#OtherTok("<-");#NormalTok(" ");#FloatTok("5.25");],
[#NormalTok("var_a");],));
#block[
#Skylighting(([#NormalTok("[1] 5.25");],));
]
]
A special form of a numeric variable is an #strong[integer] variable, which is used for whole numbers.

#block[
#Skylighting(([#NormalTok("var_b ");#OtherTok("<-");#NormalTok(" ");#DecValTok("6");],
[#NormalTok("var_b");],));
#block[
#Skylighting(([#NormalTok("[1] 6");],));
]
]
The second is #strong[character], which is used for text (named #strong[strings] in programming language). Strings in character variables must be enclosed with speech marks:

#block[
#Skylighting(([#NormalTok("var_c ");#OtherTok("<-");#NormalTok(" ");#StringTok("\"This is a string\"");],
[#NormalTok("var_c");],));
#block[
#Skylighting(([#NormalTok("[1] \"This is a string\"");],));
]
#Skylighting(([#CommentTok("# \"This\" and \"is\" would be treated by R as two separate strings");],));
]
Finally, we have #strong[logical] variables, which can take on the form of #NormalTok("TRUE"); or #NormalTok("FALSE");. #NormalTok("TRUE"); and #NormalTok("FALSE"); (or alternatively #NormalTok("T"); or #NormalTok("F");) are special values in R that, as their names suggest, are used to indicate when a certain value is true or false.

#block[
#Skylighting(([#NormalTok("var_d ");#OtherTok("<-");#NormalTok(" ");#ConstantTok("TRUE");],
[#NormalTok("var_d");],));
#block[
#Skylighting(([#NormalTok("[1] TRUE");],));
]
]
== Data structures
<data-structures>
Of course, in R we don't usually work with single values. We instead work with larger data structures. While there are a number of data structures in R, by and large the main one we will work with are #strong[data frames.]

=== Vectors
<vectors>
Vectors are extremely important in R: so much so that many functions are what we call #emph[vectorised], meaning that they operate over vectors. Vectors are a data structure that provide an ordered list of values of the same type. Vectors can contain multiple numbers, strings or logical values, as an example.

To create a vector, the #NormalTok("c()"); function is used. Below is a vector containing 5 numbers, thereby making it a vector of numerics:

#block[
#Skylighting(([#NormalTok("vector_a ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("4");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("6");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(")");],
[],
[#NormalTok("vector_a");],));
#block[
#Skylighting(([#NormalTok("[1] 4 1 6 2 3");],));
]
]
Each value in the vector has an #strong[index], which denotes its position in the vector starting from 1. We can pull values from vectors by using square brackets, #NormalTok("[]");. We give R the name of the vector, followed by the index of the value we want. Let us pull the number 1, for instance, which has an index of 2 (as it is 2nd in the vector):

#block[
#Skylighting(([#NormalTok("vector_a[");#DecValTok("2");#NormalTok("]");],));
#block[
#Skylighting(([#NormalTok("[1] 1");],));
]
]
To subset multiple values, we can simply give a vector of indices within the square brackets. For example, let's say we want to pull values from indices 2-4. This means that our output should be 1, 6 and 2. We can create a vector corresponding to the indices that we want (#NormalTok("c(2, 3, 4)");), and give this to the square brackets for subsetting.

#block[
#Skylighting(([#NormalTok("vector_a[");#FunctionTok("c");#NormalTok("(");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok(")]");],));
#block[
#Skylighting(([#NormalTok("[1] 1 6 2");],));
]
]
But there's a neater trick here that R allows you to do. When placing a semicolon, #NormalTok(":");, between two numbers, R will create a vector of numbers between the two numbers you give. The below command, for example, will create a vector of integers between the numbers 2 and 7:

#block[
#Skylighting(([#DecValTok("2");#SpecialCharTok(":");#DecValTok("7");],));
#block[
#Skylighting(([#NormalTok("[1] 2 3 4 5 6 7");],));
]
]
We can use this to great effect by subsetting multiple values from a vector at once:

#block[
#Skylighting(([#NormalTok("vector_a[");#DecValTok("2");#SpecialCharTok(":");#DecValTok("4");#NormalTok("]");],));
#block[
#Skylighting(([#NormalTok("[1] 1 6 2");],));
]
]
=== Data frames
<dataframes>
Data frames are flexible, row-column structures that contain data. Data frames can essentially be thought of as several vectors joined together as columns.

R works best when data frames are in a #emph[tidy] format. In a tidy format:

- Each variable is its own column
- Each observation (participant, object) is its own row
- Each value is in its own cell.

#figure([
#box(image("index_files\\mediabag\\tidy-1.png"))
], caption: figure.caption(
position: bottom, 
[
Adapted from R4DS.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


Here is an example of a data frame in tidy format. Note how each column corresponds to a different variable, or piece of data that we're interested in. Each column is also clearly labelled, so it is clear what it represents. Each row corresponds to an observation (a single penguin, in this case). So, the first row represnts an Adelie penguin on Torgersen Island, with a bill length of 39.1mm etc etc.

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(palmerpenguins)");],));
#block[
#Skylighting(([],
[#NormalTok("Attaching package: 'palmerpenguins'");],));
]
#block[
#Skylighting(([#NormalTok("The following objects are masked from 'package:datasets':");],
[],
[#NormalTok("    penguins, penguins_raw");],));
]
#Skylighting(([#NormalTok("penguins");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 344 × 8");],
[#NormalTok("   species island    bill_length_mm bill_depth_mm flipper_length_mm body_mass_g");],
[#NormalTok("   <fct>   <fct>              <dbl>         <dbl>             <int>       <int>");],
[#NormalTok(" 1 Adelie  Torgersen           39.1          18.7               181        3750");],
[#NormalTok(" 2 Adelie  Torgersen           39.5          17.4               186        3800");],
[#NormalTok(" 3 Adelie  Torgersen           40.3          18                 195        3250");],
[#NormalTok(" 4 Adelie  Torgersen           NA            NA                  NA          NA");],
[#NormalTok(" 5 Adelie  Torgersen           36.7          19.3               193        3450");],
[#NormalTok(" 6 Adelie  Torgersen           39.3          20.6               190        3650");],
[#NormalTok(" 7 Adelie  Torgersen           38.9          17.8               181        3625");],
[#NormalTok(" 8 Adelie  Torgersen           39.2          19.6               195        4675");],
[#NormalTok(" 9 Adelie  Torgersen           34.1          18.1               193        3475");],
[#NormalTok("10 Adelie  Torgersen           42            20.2               190        4250");],
[#NormalTok("# ℹ 334 more rows");],
[#NormalTok("# ℹ 2 more variables: sex <fct>, year <int>");],));
]
]
For the purposes of RPMP you won't need to create any data frames, but you will need to know how to read files in and work with them.

With data frames, there are a number of functions in base R that allow us to do certain operations. These will be super useful in a range of scenarios.

First, it helps to understand that data frames are (conceptually) like matrices, in that they have rows and columns that are indexed. We can therefore pull out bits of information by the row or column index (i.e.~number) using R. To do so, we can use the format #NormalTok("name[row, column]");. #NormalTok("name"); in this instance is the name of our data frame, while #NormalTok("row"); and #NormalTok("column"); are the row and column numbers we want respectively. For example, let us take the cell corresponding to the first row and the first column:

#block[
#Skylighting(([#NormalTok("penguins[");#DecValTok("1");#NormalTok(",");#DecValTok("1");#NormalTok("]");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 1");],
[#NormalTok("  species");],
[#NormalTok("  <fct>  ");],
[#NormalTok("1 Adelie ");],));
]
]
Or, the cell in row 3, column 4:

#block[
#Skylighting(([#NormalTok("penguins[");#DecValTok("3");#NormalTok(",");#DecValTok("4");#NormalTok("]");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 1");],
[#NormalTok("  bill_depth_mm");],
[#NormalTok("          <dbl>");],
[#NormalTok("1            18");],));
]
]
We can pull out whole rows or columns by simply leaving the number blank. If we want all values in a row, we do not specify a column and vice versa. For example, let us take all of row 1 from the #NormalTok("penguins"); dataset:

#block[
#Skylighting(([#NormalTok("penguins[");#DecValTok("1");#NormalTok(",]");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 8");],
[#NormalTok("  species island    bill_length_mm bill_depth_mm flipper_length_mm body_mass_g");],
[#NormalTok("  <fct>   <fct>              <dbl>         <dbl>             <int>       <int>");],
[#NormalTok("1 Adelie  Torgersen           39.1          18.7               181        3750");],
[#NormalTok("# ℹ 2 more variables: sex <fct>, year <int>");],));
]
]
Or let's take all of the species column only, which is column 1:

#block[
#Skylighting(([#NormalTok("penguins[,");#DecValTok("1");#NormalTok("]");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 344 × 1");],
[#NormalTok("   species");],
[#NormalTok("   <fct>  ");],
[#NormalTok(" 1 Adelie ");],
[#NormalTok(" 2 Adelie ");],
[#NormalTok(" 3 Adelie ");],
[#NormalTok(" 4 Adelie ");],
[#NormalTok(" 5 Adelie ");],
[#NormalTok(" 6 Adelie ");],
[#NormalTok(" 7 Adelie ");],
[#NormalTok(" 8 Adelie ");],
[#NormalTok(" 9 Adelie ");],
[#NormalTok("10 Adelie ");],
[#NormalTok("# ℹ 334 more rows");],));
]
]
The above operation actually can be done another way in R, and perhaps a way that is more intuitive. With data frames, we can grab individual columns using the #NormalTok("$"); operator, followed by the column's #emph[name]. This lets us grab columns by their name.

#block[
#Skylighting(([#NormalTok("penguins");#SpecialCharTok("$");#NormalTok("species");],));
#block[
#Skylighting(([#NormalTok("  [1] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok("  [8] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [15] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [22] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [29] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [36] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [43] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [50] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [57] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [64] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [71] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [78] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [85] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [92] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok(" [99] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok("[106] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok("[113] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok("[120] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok("[127] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok("[134] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok("[141] Adelie    Adelie    Adelie    Adelie    Adelie    Adelie    Adelie   ");],
[#NormalTok("[148] Adelie    Adelie    Adelie    Adelie    Adelie    Gentoo    Gentoo   ");],
[#NormalTok("[155] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[162] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[169] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[176] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[183] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[190] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[197] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[204] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[211] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[218] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[225] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[232] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[239] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[246] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[253] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[260] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[267] Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo    Gentoo   ");],
[#NormalTok("[274] Gentoo    Gentoo    Gentoo    Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[281] Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[288] Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[295] Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[302] Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[309] Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[316] Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[323] Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[330] Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[337] Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap Chinstrap");],
[#NormalTok("[344] Chinstrap");],
[#NormalTok("Levels: Adelie Chinstrap Gentoo");],));
]
]
Note though that the output here is different; it simply returns a vector, while the #NormalTok("[row,column]"); notation returns a data frame. Given that many functions in R rely on vectors, this notation is often useful.

Finally, if we want to select multiple rows or columns then we need to give vectors to the row and/or column arguments within the square brackets. This means that our semicolon notation will work here as well. For instance, let's say we want to get the first 6 rows of the dataset:

#block[
#Skylighting(([#NormalTok("penguins[");#DecValTok("1");#SpecialCharTok(":");#DecValTok("6");#NormalTok(",]");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 8");],
[#NormalTok("  species island    bill_length_mm bill_depth_mm flipper_length_mm body_mass_g");],
[#NormalTok("  <fct>   <fct>              <dbl>         <dbl>             <int>       <int>");],
[#NormalTok("1 Adelie  Torgersen           39.1          18.7               181        3750");],
[#NormalTok("2 Adelie  Torgersen           39.5          17.4               186        3800");],
[#NormalTok("3 Adelie  Torgersen           40.3          18                 195        3250");],
[#NormalTok("4 Adelie  Torgersen           NA            NA                  NA          NA");],
[#NormalTok("5 Adelie  Torgersen           36.7          19.3               193        3450");],
[#NormalTok("6 Adelie  Torgersen           39.3          20.6               190        3650");],
[#NormalTok("# ℹ 2 more variables: sex <fct>, year <int>");],));
]
]
Or, columns 2 to 4:

#block[
#Skylighting(([#NormalTok("penguins[,");#DecValTok("2");#SpecialCharTok(":");#DecValTok("4");#NormalTok("]");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 344 × 3");],
[#NormalTok("   island    bill_length_mm bill_depth_mm");],
[#NormalTok("   <fct>              <dbl>         <dbl>");],
[#NormalTok(" 1 Torgersen           39.1          18.7");],
[#NormalTok(" 2 Torgersen           39.5          17.4");],
[#NormalTok(" 3 Torgersen           40.3          18  ");],
[#NormalTok(" 4 Torgersen           NA            NA  ");],
[#NormalTok(" 5 Torgersen           36.7          19.3");],
[#NormalTok(" 6 Torgersen           39.3          20.6");],
[#NormalTok(" 7 Torgersen           38.9          17.8");],
[#NormalTok(" 8 Torgersen           39.2          19.6");],
[#NormalTok(" 9 Torgersen           34.1          18.1");],
[#NormalTok("10 Torgersen           42            20.2");],
[#NormalTok("# ℹ 334 more rows");],));
]
]
== Packages and functions
<packages-and-functions>
=== Functions
<functions>
R works primarily with #strong[functions], which take one or more inputs and return an output. Functions in R are always defined in #NormalTok("name()"); format, i.e.~the name of the function followed by brackets. Every function generally serves a very specific purpose, such as performing a specific calculation, manipulation of data or otherwise. Therefore, working with R requires us to use lots and lots of functions.

Most functions will have at least one, if not multiple #strong[arguments.] Arguments define the options for a given function. For example, the #NormalTok("class()"); function, which comes in base R, tells us the type of a variable. #NormalTok("class()"); has one main argument, #NormalTok("x"); - which is simply the name of the variable we want to know about. As an example, let us say we wanted to know what type of variable #NormalTok("var_a"); was. We could write the following:

#block[
#Skylighting(([#FunctionTok("class");#NormalTok("(");#AttributeTok("x =");#NormalTok(" var_a)");],));
#block[
#Skylighting(([#NormalTok("[1] \"numeric\"");],));
]
]
More simply, because #NormalTok("class()"); only has one argument we can optionally write:

#block[
#Skylighting(([#FunctionTok("class");#NormalTok("(var_a)");],));
#block[
#Skylighting(([#NormalTok("[1] \"numeric\"");],));
]
]
Functions may either have mandatory or optional arguments. Mandatory arguments are ones that you need to provide in order for the function to run. Optional arguments are often defaults that can be changed if needed. Many functions in R will have multiple arguments that are typically a mix of both. A key point arises here though: functions in R define arguments in specific orders. In other words, R expects you to input arguments in specific orders unless you explicitly define each argument's value, as we did for the first instance of #NormalTok("class()");.

The easiest way to find out information about what a function does and the arguments it requires is to type a question mark, #NormalTok("?");, with the name of the function immediately afterwards. e.g.~

#block[
#Skylighting(([#NormalTok("?class");],));
]
A basic function is the #NormalTok("round()"); function, which - as the name suggests - rounds a value you give it. #NormalTok("round()"); has two arguments: #NormalTok("x");, which is the number or the name of an object we want to round, and #NormalTok("digits");, which specifies the number of digits we want to round to. #NormalTok("x"); is a mandatory argument, but #NormalTok("digits"); is optional and has a preset value of 0. Therefore, if we type in the following you can see what we get:

#block[
#Skylighting(([#FunctionTok("round");#NormalTok("(");#FloatTok("4.326");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 4");],));
]
]
If we want to round to 2dp, for instance, we would need to explicitly define the #NormalTok("digits"); argument and set it to a different value.

#block[
#Skylighting(([#FunctionTok("round");#NormalTok("(");#FloatTok("4.326");#NormalTok(", ");#AttributeTok("digits =");#NormalTok(" ");#DecValTok("2");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 4.33");],));
]
]
=== Packages
<packages>
By default, R comes with #emph[lots] of functions, many of which will be used throughout this book. The beauty of R though is that its functionality is essentially limitless; its open-source nature and strong community mean that new functions and capabilities are regularly made for R. These new functions augment/extend what R is capable of doing, and are generally available in the form of #strong[packages.] To provide a very simple explanation of what packages are, packages are a collection of code that provide extra functions in R. Some packages occassionally come with data too, such as the #NormalTok("palmerpenguins"); package.

When you start a new R session, the first thing that you'll want to do is load the packages that you need to use.

For now, we'll load two packages for functions: #NormalTok("tidyverse"); and #NormalTok("rstatix");. #NormalTok("tidyverse"); is a huge package that contains a group of other packages designed for data manipulation, visualisation and cleaning. #NormalTok("rstatix"); allows for simple statistical tests to be performed in an easy way. #NormalTok("palmerpenguins"); comes with a dataset for practicing on. #NormalTok("palmerpenguins"); loads a dataset named #NormalTok("penguins"); that contains basic info on 3 species of penguins across 3 different islands.#footnote[In 2025, this dataset was added to the #NormalTok("datasets"); package that comes with base R - meaning that the #NormalTok("penguins"); data is now part of base R (yay!). This means that in newer versions of R, you can also access this dataset by simply using #NormalTok("data(penguins)"); without needing to load the #NormalTok("palmerpenguins"); package first. I haven't changed this though for demonstration reasons.]

To load a package, call the #NormalTok("library()"); function and enter the name of the package in brackets:

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(tidyverse)");],));
#block[
#Skylighting(([#NormalTok("── Attaching core tidyverse packages ──────────────────────── tidyverse 2.0.0 ──");],
[#NormalTok("✔ dplyr     1.2.1     ✔ readr     2.2.0");],
[#NormalTok("✔ forcats   1.0.1     ✔ stringr   1.6.0");],
[#NormalTok("✔ ggplot2   4.0.2     ✔ tibble    3.3.1");],
[#NormalTok("✔ lubridate 1.9.5     ✔ tidyr     1.3.2");],
[#NormalTok("✔ purrr     1.2.2     ");],
[#NormalTok("── Conflicts ────────────────────────────────────────── tidyverse_conflicts() ──");],
[#NormalTok("✖ dplyr::filter() masks stats::filter()");],
[#NormalTok("✖ dplyr::lag()    masks stats::lag()");],
[#NormalTok("ℹ Use the conflicted package (<http://conflicted.r-lib.org/>) to force all conflicts to become errors");],));
]
#Skylighting(([#FunctionTok("library");#NormalTok("(rstatix)");],));
#block[
#Skylighting(([],
[#NormalTok("Attaching package: 'rstatix'");],
[],
[#NormalTok("The following object is masked from 'package:stats':");],
[],
[#NormalTok("    filter");],));
]
#Skylighting(([#FunctionTok("library");#NormalTok("(palmerpenguins)");],));
]
=== The #NormalTok("tidyverse");
<the-tidyverse>
The tidyverse is a mega-collection of phenomenal packages that fundamentally change how to interface with R. The tidyverse provides packages for things like:

- Wrangling data
- Reading and writing data
- Making graphs
- Tidying and reshaping data
- Scraping the web

The tidyverse is probably the single most popular suite of packages for R because of the functionality it provides. All of the tidyverse packages are written in consistent syntax, generally use very easy language that has an emphasis on verbs (i.e.~you're telling R to #emph[do] something) and integrate seamlessly with each other and R. The tidyverse is a philosophy of R just as much as it is a suite of functions, and is part of what makes R so powerful today.

Many aspects of the tidyverse are reliant on the pipe operator, #NormalTok("%>%");. This basically tells R to take a dataframe or output and pass it onto a function that comes directly afterwards. Any function that takes a data frame as its first argument can (theoretically) be piped, meaning that we can chain strings of functions together in one run in a readable way. See the example below:

#block[
#Skylighting(([#NormalTok("data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("function_1");#NormalTok("() ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("function_2");#NormalTok("(");#AttributeTok("do =");#NormalTok(" ");#StringTok("\"this\"");#NormalTok(") ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("function_3");#NormalTok("(");#AttributeTok("avoid =");#NormalTok(" ");#StringTok("\"that\"");#NormalTok(")");],));
]
in the hypothetical example above, we first take #NormalTok("data");, and pass it to function 1. We then take the output of function 1 and pass that to function 2, which has the argument #NormalTok("do = \"this\"");. Afterwards, we take the output of function 2 and pass it to function 3.

There are a number of clear benefits to the tidyverse way of doing things. These include:

- Functions are generally stated as #emph[verbs], which means that you're always #emph[doing] something with a function (and it's clear what that something is)
- Piping avoids the cyclical hell of creating intermediate variables. Consider a non-tidyverse version of the code example above, written down below. This code is not only a bit of a pain to read, but is also clunky in that it generates several intermediate variables that aren't all that useful (a lot of the time).

#block[
#Skylighting(([#NormalTok("output_1 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("function_1");#NormalTok("(data)");],
[#NormalTok("output_2 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("function_2");#NormalTok("(output_1, ");#AttributeTok("do =");#NormalTok(" ");#StringTok("\"this\"");#NormalTok(")");],
[#NormalTok("output_3 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("function_3");#NormalTok("(output_2, ");#AttributeTok("avoid =");#NormalTok(" ");#StringTok("\"that\"");#NormalTok(")");],));
]
- Piped code is generally quite easy to read.
- #NormalTok("tidyverse"); also provides a consistent syntax for #emph[other] packages! It provides a quasi-philosophy and style guide for developers to write their own packages to write 'tidy' packages. #NormalTok("rstatix"); is a great example of this.

Throughout this book you will see a lot of tidyverse!

=== The #NormalTok("here"); package
<the-here-package>
Another staple bit of code you will see throughout RPMP is the #NormalTok("here"); package. The official vignette for #NormalTok("here"); summarises what this package does:

#quote(block: true)[
The #NormalTok("here"); package enables easy file referencing by using the top-level directory of a file project to easily build file paths. This is in contrast to using #NormalTok("setwd()");, which is fragile and dependent on the way you order your files on your computer.
]

Alternatively, read the below quote from R goddess Jenny Bryan:

#quote(block: true)[
If the first line of your \#rstats script is #NormalTok("setwd(\"C:\\Users\\jenny\\path\\that\\only\\I\\have\")");, I will come into your lab and SET YOUR COMPUTER ON FIRE.
]

In short, #NormalTok("here()"); allows us to locate files in a #emph[relative] manner as opposed to an #emph[absolute] one. This is super super useful for sharing your code and data with other people, and ensuring that your scripts will run no matter where they are.

Imagine you have a folder structure like this:

#Skylighting(([#NormalTok("|-code");],
[#NormalTok("|-----rpmp_week1.Rmd");],
[#NormalTok("|-data");],
[#NormalTok("|-----w1_dataset.csv");],
[#NormalTok("|-output");],
[#NormalTok("|-RPMP.rproj");],));
Normally, to locate a file on a disk you would generally have to give the entire pathway to that file. That could be something like #NormalTok("\"C:\\Users\\Dan\\Documents\\Subjects\\RPMP\\data\\w1_dataset.csv\""); - which is immensely unwieldy if we want to read in data - and won't work the moment I give my script to someone else, as their folder structure could be completely different!

The alternative with #NormalTok("here()"); could be as simple as:

#block[
#Skylighting(([#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"w1_dataset.csv\"");#NormalTok(")");],));
]
This tells R that I'm looking for something #NormalTok("here"); in the #NormalTok("data"); folder, specifically a file named #NormalTok("w1_dataset.csv");. As long as the relative positions are correct - i.e.~the #NormalTok(".csv"); file is in the #NormalTok("data"); folder - R will know where to locate the file.

You will see a lot of #NormalTok("here()"); in this version of the RPMP guide because as you may appreciate, there are a lot of data files stored in all manner of folders. We will talk specifically about using this function to read in data on the next page!

== Loading data into R
<loading-data-into-r>
Naturally, we cannot do any statistical analyses without reading in data. R can flexibly read in a number of data formats.

=== Setting up R projects
<setting-up-r-projects>
Before we continue, it's worth taking a moment here to pick up on the project workflow we mentioned on the previous page. By default, R will operate out of your #NormalTok("Documents"); folder on both Windows and macOS. If you make an #strong[R project], you can essentially create an instance of R that starts from the folder you place your R project in. This can be really useful for keeping all of your files related to one project in one place!

There are several guides online on how to initialise R projects, so we will not try to reinvent the wheel here. However, the basic idea is something like this:L

+ Create a new R project.
+ While creating the new project, either create a new folder for it or assign it to the existing folder. This will create an #strong[.rproj] file in that folder.
+ When working on a project, #strong[open the .rproj] file. This will open RStudio in that #emph[project], which you can think of as an instance of R Studio.
+ Work away!

An example basic project structure might look like this:

#Skylighting(([#NormalTok("|-Documents");],
[#NormalTok("|---RPMP (this is the folder for the project)");],
[#NormalTok("|-----RPMP.rproj");],));
The .rproj file will sit within the folder you specify, meaning that all your files and filepaths will be indexed relative to that folder. For #NormalTok("here");, this means that you will now start from the #emph[RPMP] folder, and not #NormalTok("Documents");. As we will touch on below, this is really useful for easily finding files!

At a basic level, we recommend a simple file structure like this:

#Skylighting(([#NormalTok("|-Documents");],
[#NormalTok("|---RPMP (this is the folder for the project)");],
[#NormalTok("|-----RPMP.rproj");],
[#NormalTok("|-----code");],
[#NormalTok("|-----data");],
[#NormalTok("|-----output");],));
The #NormalTok("code"); folder in your project is your place for storing code, the #NormalTok("data"); folder is for storing data and #NormalTok("output"); is useful for saving any outputs you generate.

=== csv files
<csv-files>
By and large, the most common file format for R is the #strong[.csv] file format. .csv stands for #strong[comma separated values], and is basically a file format that stores your data in text form, separated by commas. The commas indicate where your data's #emph[columns] are, and thus

The basic structure of a .csv file is identical to that of a regular dataframe in R. The first column should typically indicate the column name/heading, and each row should contain values.

.csvs can be easily created using Excel. If you have a dataset in Excel format, you can export an Excel spreadsheet as a .csv file by going File -\> Export. However, as .csv files are stored as plain text, they will not retain any special formatting that you might be accustomed to in an Excel spreadsheet. They will only store data in plain text.

To read a .csv file in R, the #NormalTok("read_csv()"); function from #NormalTok("tidyverse"); or #NormalTok("read.csv()"); from base R will work equally as well. Both functions require you to specify where your .csv file can be found.

#block[
#Skylighting(([#NormalTok("dataset ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#StringTok("\"Insert your file path here.csv\"");#NormalTok(")");],));
]
=== Text files
<text-files>
R can also read in plain text files in .txt format. This is very similar to the .csv format, in that your text file will typically have column headers in the first row, each row with one participant/observation's values, and each column separated by spaces.

#NormalTok("tidyverse"); provides a function called #NormalTok("read_tsv()"); to read in these files.

#block[
#Skylighting(([#NormalTok("dataset ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_tsv");#NormalTok("(");#StringTok("\"Insert your file path here.txt\"");#NormalTok(")");],));
]
If, however, you are working with a file that has a different type of character between each column - for example, a slash (/) - then you can use the function #NormalTok("read_delim()");, which is a more generic form of the two above. With this function, you must specify the #strong[delimiter] - i.e.~what separates the columns in the files. This can be done using the #NormalTok("delim ="); argument.

#block[
#Skylighting(([#NormalTok("dataset ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_delim");#NormalTok("(");#StringTok("\"Insert your file path here.txt\"");#NormalTok(", ");#AttributeTok("delim =");#NormalTok(" ");#StringTok("\"/\"");#NormalTok(")");],));
]
=== SPSS files
<spss-files>
SPSS is still a popular program of choice in psychological sciences, and so a lot of the datasets you may come across may be in SPSS format. SPSS data files are in #strong[.sav] format.

Base R cannot natively read these files. However, the #NormalTok("haven"); package provides a function called #NormalTok("read_spss()"); that will read these files in for you.

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(haven)");],
[#NormalTok("dataset ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_spss");#NormalTok("(");#StringTok("\"Insert your file path here.sav\"");#NormalTok(")");],));
]
=== Using #NormalTok("here"); to read data
<using-here-to-read-data>
On the previous page, we talked about the #NormalTok("here"); package, and how it enables easy pathing. #NormalTok("here"); becomes really useful for reading in data, and it becomes even easier if you have an R project set up.

If you have a project structure like the example on the previous page:

#Skylighting(([#NormalTok("|-RPMP");],
[#NormalTok("|---code");],
[#NormalTok("|-----rpmp_week1.Rmd");],
[#NormalTok("|---data");],
[#NormalTok("|-----w1_dataset.csv");],
[#NormalTok("|---output");],
[#NormalTok("|---RPMP.rproj");],));
Then you can use #NormalTok("here()"); in conjunction with any of the data-reading functions above. As the data-reading functions primarily only need a filepath, you can use #NormalTok("here()"); to create that filepath and point to the right place.

Here is an example:

#block[
#Skylighting(([#NormalTok("dataset ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"w1_dataset.csv\"");#NormalTok("))");],));
]
The #NormalTok("here()"); call tells R to look in the #NormalTok("data"); folder, and then look for #NormalTok("w1_dataset.csv");. Remember, in an R project, every file is indexed relative to the #emph[project] folder. This means that we don't need to faff around with finding out where our RPMP folder is on our computer, because essentially that's where we start! The filepath to this file will then be used as the argument for #NormalTok("read_csv()");.

Even if you are not using a project structure (although we highly recommend you do), you can still use #NormalTok("here()"); - so long as the file can be located relative to your current working directory, which can be obtained using #NormalTok("setwd()");. However, it's usually worth saving yourself the hassle and creating a new R project for substantive bits of work, and saving files as folders within that project's folder.

== Wrangling data with #NormalTok("dplyr"); and others
<wrangling-data-with-dplyr-and-others>
#NormalTok("dplyr"); is a package within the tidyverse for manipulating and wrangling data. #NormalTok("dplyr"); is one of the most popular packages on R because it provides a suite of functions that are fairly essential to manipulating and working with data. Below is a brief overview of some of these functions, applied to the #NormalTok("penguins"); dataset.

=== Selecting columns with #NormalTok("select()");
<selecting-columns-with-select>
#NormalTok("select()"); lets you select the columns you want from a dataset. Simply specify the columns that you want by name. Below we take the species and island columns from the penguins dataset:

#block[
#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(species, island)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 344 × 2");],
[#NormalTok("   species island   ");],
[#NormalTok("   <fct>   <fct>    ");],
[#NormalTok(" 1 Adelie  Torgersen");],
[#NormalTok(" 2 Adelie  Torgersen");],
[#NormalTok(" 3 Adelie  Torgersen");],
[#NormalTok(" 4 Adelie  Torgersen");],
[#NormalTok(" 5 Adelie  Torgersen");],
[#NormalTok(" 6 Adelie  Torgersen");],
[#NormalTok(" 7 Adelie  Torgersen");],
[#NormalTok(" 8 Adelie  Torgersen");],
[#NormalTok(" 9 Adelie  Torgersen");],
[#NormalTok("10 Adelie  Torgersen");],
[#NormalTok("# ℹ 334 more rows");],));
]
]
You can select columns via a number of ways:

- Simply by name, e.g.~#NormalTok("select(species, island)");
- By their #emph[index] or column number, e.g.~#NormalTok("select(1, 2)");
  - #NormalTok("select(1:4)"); will select columns 1 to 4
  - #NormalTok("select(-1)"); will select the #emph[last] column
- By certain operator functions, such as #NormalTok("starts_with()"); and #NormalTok("ends_with()");, e.g.~#NormalTok("ends_with(\"mm\")"); will select all columns that end with "mm"

Combinations of the above also work. Removing columns is simply done by adding a minus sign #NormalTok("-"); in front of the arguments for select, and are compatible with all of the options above.

=== Filtering rows with #NormalTok("filter()");
<filtering-rows-with-filter>
#NormalTok("filter()"); selects the rows that you want based on a certain condition. Here, we specify the column that want to filter by and state the condition (#NormalTok("=="); means equals to). We can filter on multiple conditions; for example, filtering Adelie penguins by the year 2007:

#block[
#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(year ");#SpecialCharTok("==");#NormalTok(" ");#DecValTok("2007");#NormalTok(", species ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"Adelie\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 50 × 8");],
[#NormalTok("   species island    bill_length_mm bill_depth_mm flipper_length_mm body_mass_g");],
[#NormalTok("   <fct>   <fct>              <dbl>         <dbl>             <int>       <int>");],
[#NormalTok(" 1 Adelie  Torgersen           39.1          18.7               181        3750");],
[#NormalTok(" 2 Adelie  Torgersen           39.5          17.4               186        3800");],
[#NormalTok(" 3 Adelie  Torgersen           40.3          18                 195        3250");],
[#NormalTok(" 4 Adelie  Torgersen           NA            NA                  NA          NA");],
[#NormalTok(" 5 Adelie  Torgersen           36.7          19.3               193        3450");],
[#NormalTok(" 6 Adelie  Torgersen           39.3          20.6               190        3650");],
[#NormalTok(" 7 Adelie  Torgersen           38.9          17.8               181        3625");],
[#NormalTok(" 8 Adelie  Torgersen           39.2          19.6               195        4675");],
[#NormalTok(" 9 Adelie  Torgersen           34.1          18.1               193        3475");],
[#NormalTok("10 Adelie  Torgersen           42            20.2               190        4250");],
[#NormalTok("# ℹ 40 more rows");],
[#NormalTok("# ℹ 2 more variables: sex <fct>, year <int>");],));
]
]
You can also choose to filter #emph[out] rows based on a condition by adding an exclamation mark in front of the column name.

#block[
#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(");#SpecialCharTok("!");#NormalTok("year ");#SpecialCharTok("==");#NormalTok(" ");#DecValTok("2007");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 234 × 8");],
[#NormalTok("   species island bill_length_mm bill_depth_mm flipper_length_mm body_mass_g");],
[#NormalTok("   <fct>   <fct>           <dbl>         <dbl>             <int>       <int>");],
[#NormalTok(" 1 Adelie  Biscoe           39.6          17.7               186        3500");],
[#NormalTok(" 2 Adelie  Biscoe           40.1          18.9               188        4300");],
[#NormalTok(" 3 Adelie  Biscoe           35            17.9               190        3450");],
[#NormalTok(" 4 Adelie  Biscoe           42            19.5               200        4050");],
[#NormalTok(" 5 Adelie  Biscoe           34.5          18.1               187        2900");],
[#NormalTok(" 6 Adelie  Biscoe           41.4          18.6               191        3700");],
[#NormalTok(" 7 Adelie  Biscoe           39            17.5               186        3550");],
[#NormalTok(" 8 Adelie  Biscoe           40.6          18.8               193        3800");],
[#NormalTok(" 9 Adelie  Biscoe           36.5          16.6               181        2850");],
[#NormalTok("10 Adelie  Biscoe           37.6          19.1               194        3750");],
[#NormalTok("# ℹ 224 more rows");],
[#NormalTok("# ℹ 2 more variables: sex <fct>, year <int>");],));
]
]
#NormalTok("drop_na()"); is another useful starting function that simply removes all rows with NA/empty cells. If you enter it as is then it will clean the entire dataset; if you specify a column then it will remove all rows with NAs in that column. Below is an example of a pipe using these functions - going from selecting columns to filtering rows and finally cleaning up the empty cells.

#block[
#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(species, body_mass_g, year) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(year ");#SpecialCharTok("==");#NormalTok(" ");#DecValTok("2009");#NormalTok(") ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("drop_na");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 119 × 3");],
[#NormalTok("   species body_mass_g  year");],
[#NormalTok("   <fct>         <int> <int>");],
[#NormalTok(" 1 Adelie         3725  2009");],
[#NormalTok(" 2 Adelie         4725  2009");],
[#NormalTok(" 3 Adelie         3075  2009");],
[#NormalTok(" 4 Adelie         4250  2009");],
[#NormalTok(" 5 Adelie         2925  2009");],
[#NormalTok(" 6 Adelie         3550  2009");],
[#NormalTok(" 7 Adelie         3750  2009");],
[#NormalTok(" 8 Adelie         3900  2009");],
[#NormalTok(" 9 Adelie         3175  2009");],
[#NormalTok("10 Adelie         4775  2009");],
[#NormalTok("# ℹ 109 more rows");],));
]
]
=== Creating new columns with #NormalTok("mutate()");
<creating-new-columns-with-mutate>
#NormalTok("mutate()"); is a function that lets you create new columns. This can be extremely useful for operations like recoding variables and transforming them. The nice thing about #NormalTok("mutate()"); is that you can do all manner of operations without touching your original data.

The basic workflow of #NormalTok("mutate()"); looks like this:

#block[
#Skylighting(([#NormalTok("data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("new_column_1 =");#NormalTok(" ");#FunctionTok("a_function");#NormalTok("(...),");],
[#NormalTok("    ");#AttributeTok("new_column_2 =");#NormalTok(" ");#FunctionTok("another_function");#NormalTok("(...)");],
[#NormalTok("    )");],));
]
This example code would create two new columns, named #NormalTok("new_column_1"); and #NormalTok("new_column_2");, with their respective values being whatever the functions were. For example, in the #NormalTok("penguins"); dataset we have a variable called #NormalTok("body_mass_g");, which is the body mass of each penguin in grams. If we wanted to convert this to kilograms, we would need to divide each penguin's value on this variable by 1000. #NormalTok("mutate()"); makes this a piece of cake. Let's also chain a #NormalTok("select()"); command to only show the following variables: species, island, body\_mass\_g and sex.

#block[
#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(species, island, body_mass_g, sex) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("body_mass_kg =");#NormalTok(" body_mass_g");#SpecialCharTok("/");#DecValTok("1000");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 344 × 5");],
[#NormalTok("   species island    body_mass_g sex    body_mass_kg");],
[#NormalTok("   <fct>   <fct>           <int> <fct>         <dbl>");],
[#NormalTok(" 1 Adelie  Torgersen        3750 male           3.75");],
[#NormalTok(" 2 Adelie  Torgersen        3800 female         3.8 ");],
[#NormalTok(" 3 Adelie  Torgersen        3250 female         3.25");],
[#NormalTok(" 4 Adelie  Torgersen          NA <NA>          NA   ");],
[#NormalTok(" 5 Adelie  Torgersen        3450 female         3.45");],
[#NormalTok(" 6 Adelie  Torgersen        3650 male           3.65");],
[#NormalTok(" 7 Adelie  Torgersen        3625 female         3.62");],
[#NormalTok(" 8 Adelie  Torgersen        4675 male           4.68");],
[#NormalTok(" 9 Adelie  Torgersen        3475 <NA>           3.48");],
[#NormalTok("10 Adelie  Torgersen        4250 <NA>           4.25");],
[#NormalTok("# ℹ 334 more rows");],));
]
]
You can see now that we have a new column called #NormalTok("body_mass_kg"); that has our new transformed variable.

#NormalTok("mutate()"); can also take functions (and likely will make up the majority of your use of it). For example, let's say that we want to make a variable that takes the natural logarithm of bill length (for whatever reason). We could do this as follows using the #NormalTok("log()"); function within our #NormalTok("mutate()"); call:

#block[
#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(species, island, bill_length_mm, bill_depth_mm) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("bill_length_log =");#NormalTok(" ");#FunctionTok("log");#NormalTok("(bill_length_mm))");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 344 × 5");],
[#NormalTok("   species island    bill_length_mm bill_depth_mm bill_length_log");],
[#NormalTok("   <fct>   <fct>              <dbl>         <dbl>           <dbl>");],
[#NormalTok(" 1 Adelie  Torgersen           39.1          18.7            3.67");],
[#NormalTok(" 2 Adelie  Torgersen           39.5          17.4            3.68");],
[#NormalTok(" 3 Adelie  Torgersen           40.3          18              3.70");],
[#NormalTok(" 4 Adelie  Torgersen           NA            NA             NA   ");],
[#NormalTok(" 5 Adelie  Torgersen           36.7          19.3            3.60");],
[#NormalTok(" 6 Adelie  Torgersen           39.3          20.6            3.67");],
[#NormalTok(" 7 Adelie  Torgersen           38.9          17.8            3.66");],
[#NormalTok(" 8 Adelie  Torgersen           39.2          19.6            3.67");],
[#NormalTok(" 9 Adelie  Torgersen           34.1          18.1            3.53");],
[#NormalTok("10 Adelie  Torgersen           42            20.2            3.74");],
[#NormalTok("# ℹ 334 more rows");],));
]
]
=== Summarising data with #NormalTok("summarise()"); and #NormalTok("group_by()");
<summarising-data-with-summarise-and-group_by>
Finally, sometimes we will want to summarise data - for example, to calculate basic features such as descriptives or for plotting. To do that, we can use the function #NormalTok("summarise()"); (or #NormalTok("summarize()"); for American users).

#NormalTok("summarise()"); works very similarly to #NormalTok("mutate()");.

#block[
#Skylighting(([#NormalTok("data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("summary_1 =");#NormalTok(" ");#FunctionTok("a_function");#NormalTok("(...),");],
[#NormalTok("    ");#AttributeTok("summary_2 =");#NormalTok(" ");#FunctionTok("another_function");#NormalTok("(...)");],
[#NormalTok("    )");],));
]
The difference is that while #NormalTok("mutate()"); retains the features of your data, #NormalTok("summarise()"); will instead collapse it. To illustrate, let's say we want to calculate a) how many penguins there are (with the function #NormalTok("n()");) and b) the mean body mass (with the #NormalTok("mean()"); function).

#block[
#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("n_penguins =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("mean_mass =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(body_mass_g, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 2");],
[#NormalTok("  n_penguins mean_mass");],
[#NormalTok("       <int>     <dbl>");],
[#NormalTok("1        344     4202.");],));
]
]
This is… good and all, but consider what we've just done. We've just calculated the number of penguins and the mean body mass across the #emph[entire] dataset. However, that may not necessarily be meaningful, particularly in this instance where we have meaningful groups within the data. For example, the above mean collapses across years, which may not be appropriate.

Enter in another function called #NormalTok("group_by()");. As the name implies, #NormalTok("group_by()"); will perform operations per a grouping variable that you specify. #NormalTok("group_by()"); works especially well with summarise, because the idea is something like this:

#block[
#Skylighting(([#NormalTok("data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(variable) ");#SpecialCharTok("%>%");#NormalTok("                 ");#CommentTok("# Tell R to group the subsequent output by this variable");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("summary_1 =");#NormalTok(" ");#FunctionTok("a_function");#NormalTok("(...),");],
[#NormalTok("    ");#AttributeTok("summary_2 =");#NormalTok(" ");#FunctionTok("another_function");#NormalTok("(...)");],
[#NormalTok("    ) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ungroup");#NormalTok("()         ");#CommentTok("# Tell R grouping is no longer needed");],));
]
Let's put this into practice by calculating the n and mean per year. Notice how the output now calculates n and the mean body mass per year, which is much more informative!

#block[
#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(year) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("n_penguins =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("mean_mass =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(body_mass_g, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#NormalTok("  ) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ungroup");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 3 × 3");],
[#NormalTok("   year n_penguins mean_mass");],
[#NormalTok("  <int>      <int>     <dbl>");],
[#NormalTok("1  2007        110     4125.");],
[#NormalTok("2  2008        114     4267.");],
[#NormalTok("3  2009        120     4210.");],));
]
]
Naturally, #NormalTok("group_by()"); can group using multiple variables. This is easy to do so as well

#block[
#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(year, island) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("n_penguins =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("mean_mass =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(body_mass_g, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#NormalTok("  ) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ungroup");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("`summarise()` has regrouped the output.");],
[#NormalTok("ℹ Summaries were computed grouped by year and island.");],
[#NormalTok("ℹ Output is grouped by year.");],
[#NormalTok("ℹ Use `summarise(.groups = \"drop_last\")` to silence this message.");],
[#NormalTok("ℹ Use `summarise(.by = c(year, island))` for per-operation grouping");],
[#NormalTok("  (`?dplyr::dplyr_by`) instead.");],));
]
#block[
#Skylighting(([#NormalTok("# A tibble: 9 × 4");],
[#NormalTok("   year island    n_penguins mean_mass");],
[#NormalTok("  <int> <fct>          <int>     <dbl>");],
[#NormalTok("1  2007 Biscoe            44     4741.");],
[#NormalTok("2  2007 Dream             46     3684.");],
[#NormalTok("3  2007 Torgersen         20     3763.");],
[#NormalTok("4  2008 Biscoe            64     4628.");],
[#NormalTok("5  2008 Dream             34     3779.");],
[#NormalTok("6  2008 Torgersen         16     3856.");],
[#NormalTok("7  2009 Biscoe            60     4793.");],
[#NormalTok("8  2009 Dream             44     3691.");],
[#NormalTok("9  2009 Torgersen         16     3489.");],));
]
]
Suddenly this is much more informative - we can now do calculations/operations per year and island, which provides a lot more nuance.

=== Some other handy tidyverse functions
<some-other-handy-tidyverse-functions>
As stated at the start of this chapter, this book will only cover enough R functions to provide you with an understanding of what goes on in this book and how. Nonetheless, there are so many tidyverse functions out there that are worth exploring and knowing about. Below is a brief list of some other functions from #NormalTok("dplyr"); you may wish to keep in mind. To find out what a given function does in more detail, you just need to type #NormalTok("?function"); into the R console to search for its documentation (or #NormalTok("??x"); to do a broad search).

Note that all of these are #NormalTok("dplyr"); functions, so need to be piped from a dataset like usual.

- #NormalTok("arrange()"); will sort your rows by a variable you specify. For example, if you wanted to sort the penguins dataset by island, you could use #NormalTok("arrange(island)"); (or #NormalTok("arrange(desc(island))"); for descending order).
- #NormalTok("distinct()"); will give you all #emph[unique] values in a given column. #NormalTok("distinct(island)");, for instance, will give you each unique island name.
- #NormalTok("rename()"); will let you rename columns.
- #NormalTok("relocate()"); will let you rearrange the column order.
- The #NormalTok("slice()"); set of functions will subset rows, but mainly based on positions (e.g.~first, last) rather than conditions.

== Making graphs with #NormalTok("ggplot2");
<ggplot>
=== Building the plot
<building-the-plot>
#NormalTok("ggplot2"); (henceforth referred to as ggplot) is the tidyverse package for plotting and visualising data. It is an immensely powerful and flexible way of graphing data in R, and is basically the de facto means of creating visualisations for R users.#footnote[Almost all of the graphs in RPMP (in fact, I think it actually is 100%) were made using #NormalTok("ggplot2");.]

The 'gg' in the name ggplot stands for #strong[grammar of graphics]. The idea is that a graph is built by #emph[layering] different components of a graph (the graphics) in a structured way (the grammar). The idea was first put forward by Leland Wilkinson, and looks something like this:

#align(center)[#box(image("img/grammar_graphics.webp"))]
A cheatsheet for ggplot can be found #link("https://rstudio.github.io/cheatsheets/html/data-visualization.html")[here].

To start a plot, we first call the #NormalTok("ggplot()"); function. Here, we specify three of the main features of our plot - the dataset that we want to use, the x axis and the y axis. the x and y axes are wrapped within the #NormalTok("aes()"); function, which defines our aesthetics. Here, we simply say which columns of our dataset should go on the x and y axes. Using the #NormalTok("penguins"); dataset, we can start to visualise a scatter plot between bill length and bill depth like this:

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" bill_length_mm, ");#AttributeTok("y =");#NormalTok(" bill_depth_mm))");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-58-1.svg"))

However, notice that the plot is empty. This is because we've only specified the first two layers of our graph: the data and the aesthetics. We haven't defined any geoms, or actual plotting methods, in our plot.

=== Geoms
<geoms>
#strong[Geoms] (short for geometries) define #emph[how] data is plotted. If #NormalTok("ggplot()"); provides the basic canvas for the graph (i.e.~#emph[what] to plot), geoms are what create the graph (i.e.~#emph[how] it is plotted). Different graph types are defined using geoms. As per the diagram of the grammar of graphics above, we add (literally, using #NormalTok("+");) additional layers to our base #NormalTok("ggplot()"); call in order to build our graph.

Refer to the cheatsheet for all of the possible geoms. For now, we will stick to some basics.

A scatter plot can be specified by adding #NormalTok("geom_point()");. This requires that your x and y variables are continuous:

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" bill_length_mm, ");#AttributeTok("y =");#NormalTok(" bill_depth_mm)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("()");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-59-1.svg"))

#NormalTok("geom_smooth()"); will add a line of best fit to a scatterplot. You can add this as another geom layer by adding #NormalTok("geom_smooth(method = \"lm\")");. Specifying the method is important because by default, #NormalTok("geom_smooth()"); will probably fit LOESS curves (local polynomial regressions). Note that this function should be added after using #NormalTok("geom_point()");.

By default, the line will also have standard error bands around it. You can turn this off by also specifying #NormalTok("se = FALSE"); in the #NormalTok("geom_smooth()"); call.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" bill_length_mm, ");#AttributeTok("y =");#NormalTok(" bill_depth_mm)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_smooth");#NormalTok("(");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"lm\"");#NormalTok(", ");#AttributeTok("se =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("`geom_smooth()` using formula = 'y ~ x'");],));
]
#box(image("01-intro_files/figure-typst/unnamed-chunk-60-1.svg"))

#NormalTok("geom_boxplot()"); will create boxplots. For this geom to work, a categorical variable must be on the x axis and a continuous variable must be on the y axis. An example is below, with species on the x axis and body mass on the y:

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" species, ");#AttributeTok("y =");#NormalTok(" body_mass_g)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_boxplot");#NormalTok("()");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-61-1.svg"))

#NormalTok("geom_violin()"); plots violin plots, which is a variant of the boxplot that also plots the distribution.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" species, ");#AttributeTok("y =");#NormalTok(" body_mass_g)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_violin");#NormalTok("()");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-62-1.svg"))

#NormalTok("geom_bar()"); and #NormalTok("geom_col()"); will both create bar plots, but their usage is slightly different. #NormalTok("geom_bar()"); is best used if you want to plot the #emph[number] of items in each category. #NormalTok("geom_col()"); is best used to plot means or similar statistics.

#Skylighting(([#NormalTok("penguins ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(species) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("mean_mass =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(body_mass_g, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#NormalTok("  ) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" species, ");#AttributeTok("y =");#NormalTok(" mean_mass)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_col");#NormalTok("()");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-63-1.svg"))

#NormalTok("geom_histogram()"); will plot a histogram, which is useful for visualising distributions. For this, you only need to provide one continuous variable on the x-axis. #NormalTok("geom_density()"); will plot the same information but using a smoothed line instead of bins.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" body_mass_g)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_histogram");#NormalTok("()");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-64-1.svg"))

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" body_mass_g)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_density");#NormalTok("()");],));
#block[
#box(image("01-intro_files/figure-typst/unnamed-chunk-64-2.svg"))

]
=== Making the graph look better
<making-the-graph-look-better>
This is all well and good, and we already have workable basic graphs using #NormalTok("ggplot");. From here, we can change many things by adding or modifying our existing layers to our ggplot. There are #emph[so] many options available here, but here we'll only focus on some basic considerations.

An important aspect of data visualisation is a good use of colour. Colours should be used in both an informative and an aesthetically appealing way. A particularly common but effective use of colour is to use different colours to denote different groups in a plot.

#NormalTok("ggplot"); provides two mechanisms within aesthetics for controlling colour. Both must typically be included in the #NormalTok("aes()"); part of #NormalTok("ggplot()");.

- #NormalTok("colour"); controls the colouring of points and lines. For graphs with shapes, such as boxplots and violin plots, this argument will control the colour of the border.
- #NormalTok("fill"); controls the colouring of anything over an area, such as bar plots, histograms and density/violin plots.

We can tell #NormalTok("gggplot"); to colour in aspects of our graph based on another variable in the dataset we are using. For example, if we want to colour a scatterplot between two vraiables by sex (which is a column in the penguins data), we can do so by specifiyng #NormalTok("colour = sex"); in our #NormalTok("aes()"); function.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" bill_length_mm, ");#AttributeTok("y =");#NormalTok(" bill_depth_mm, ");#AttributeTok("colour =");#NormalTok(" sex)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("()");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-65-1.svg"))

Many graphs allow for control of both colour and fill. In these instances, as noted above, #NormalTok("fill"); controls the colour within the shape while #NormalTok("colour"); controls the colour of the shape's edges. For example, here is a density plot that specifies both #NormalTok("colour"); and #NormalTok("fill"); to be controlled by the variable #NormalTok("island");. This has the effect of making both the borders and the area within the shape the same colour.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" body_mass_g, ");#AttributeTok("fill =");#NormalTok(" island, ");#AttributeTok("colour =");#NormalTok(" island)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_density");#NormalTok("()");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-66-1.svg"))

Now, this is all well and good but in this particular instance the overlapping of curves means that we can't actually see what is going on very well. The data points from Torgersen island, for instance, almost completely overlap with the data points from Dream Island. One way to get past this is to specify another aesthetic called #NormalTok("alpha");, which sets the #strong[transparency] of the fill.

As we typically only want to change the transparency of one type of geom in a plot, the best place to include an #NormalTok("alpha"); argument is within the geom call itself (in this case, within #NormalTok("geom_density()");). #NormalTok("alpha"); can range from 0 - 1, where 1 means an object is 100% opaque (i.e.~0% transparent) and 0 means 0% opaqueness (100% transparency). Here, we use #NormalTok("alpha = 0.5"); to set the fill to be 50% transparent:

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" body_mass_g, ");#AttributeTok("fill =");#NormalTok(" island, ");#AttributeTok("colour =");#NormalTok(" island)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_density");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.5");#NormalTok(")");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-67-1.svg"))

Now we can see the outlines of each density curve more clearly! This is great.

#NormalTok("ggplot"); also supports the manual specification of colours. R by default comes with a bunch of strings that are recognised as colours during graphing, such as #NormalTok("\"black\"");, #NormalTok("\"blue\""); and #NormalTok("\"red\"");. These can be used to manually set either the colour or the fill of a geom. To use these, you can instead use #NormalTok("colour");/#NormalTok("fill"); within the #emph[geom] like so:

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" species, ");#AttributeTok("y =");#NormalTok(" body_mass_g)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_boxplot");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"blue\"");#NormalTok(")");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-68-1.svg"))

You can also provide hexadecimal strings (e.g.~"white" corresponds to #NormalTok("\"#FFFFFF\"");). See #link(<colours>)[the Appendix] for a full list of the basic palettes in R.

Every graph needs good axis titles. By default, #NormalTok("ggplot"); will use variable names as axis labels, which often aren't very informative by default. We can change this by adding #NormalTok("labs()");, which is a simple way of specifying x and y labels:

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" bill_length_mm, ");#AttributeTok("y =");#NormalTok(" bill_depth_mm)) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Bill length (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Bill depth (mm)\"");#NormalTok(") ");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-69-1.svg"))

Finally, if you want to split plots by a certain variable, add #NormalTok("facet_wrap()"); to your call. You need to specify what variable/column you want to split by, with a tilde in front. For example, if we wanted to split the scatter plot by year:

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#AttributeTok("data =");#NormalTok(" penguins, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" bill_length_mm, ");#AttributeTok("y =");#NormalTok(" bill_depth_mm, ");#AttributeTok("colour =");#NormalTok(" sex)) ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("geom_point");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Bill length (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Bill depth (mm)\"");#NormalTok(")  ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("facet_wrap");#NormalTok("(");#SpecialCharTok("~");#NormalTok("year)");],));
#box(image("01-intro_files/figure-typst/unnamed-chunk-70-1.svg"))

You can see that the graph now creates one graph per year, which can be immensely useful for visualising data points between groups.

From here, there are so many things you can do with ggplot - and it helps to get creative!

= Descriptive statistics
<descriptives>
Descriptive statistics, as the name implies, are used to describe data. A key part of the quantitative research process is understanding the various ins and outs of your data. You'll probably have a sense of why this is important if you have the qualitative presentation still fresh in your mind - namely, knowing your data is also really important for knowing what to do with it.

In this first module, we will start with the first steps of understanding quantitative data. This involves visualising our data to see what it looks like, and describing key features of the data. If you're familiar with statistics then some of this may seem a bit trivial, but it's important that we get the basics right before we go on to doing fancy statistical tests.

#quote(block: true)[
Also, I know that the idea of doing statistics and maths freaks a lot of us out - and that's totally normal. Yes, there will be some number-crunching and maths in the next series of modules, but the focus of these modules is not to force you to calculate things by hand. You will encounter a whole bunch of mathematical formulae, but the point of doing so is to illustrate the concepts that underpin them. These concepts are crucial to understanding the 'magic' that happens with quantitative analysis, and a really solid foundation in statistical concepts will go a long way.
]

#quote(block: true)[
That being said, throughout these statistics modules there will be a number of activities that ask you to actively work with sample datasets and analyse them. We promise that you will get so much more out of these modules if you complete these activities, because readings and webpages aren't the best substitute for actually doing it and getting your hands dirty with data.
]

By the end of this module you should be able to:

- Create both appropriate and meaningful graphs from data
- Calculate various forms of descriptive statistics
- Interpret both graphs and descriptive statistics, and explain what they tell you

#figure([
#box(image("index_files\\mediabag\\statistics.png"))
], caption: figure.caption(
position: bottom, 
[
#link("https://xkcd.com/2400/")[xkcd: Statistics]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


== Visualising data
<visualising-data>
#block(fill: rgb("#f5f5f5"))[
When you have data in your hand, it is often tempting to dive straight into plugging it into an analysis and seeing what the results are. However, in general this is unwise. The first step in working with quantitative data is to see what your data looks like. Looking at the data can give us a first glance into many aspects of the results, which can be informative for analyses.

]
=== Why visualise data?
<why-visualise-data>
#quote(block: true)[
"The greatest value of a picture is when it forces us to notice what we never expected to see." -John W. Tukey
]

One of the first steps in working with quantitative data is #strong[data visualisation], which is the process of graphing it and looking at it. If you work with quantitative data then it should become standard practice for you to graph your data: specifically, #emph[after] you've defined your research questions and methods of analysis, but #emph[before] you actually analyse it.

It's common for many students learning research methods and statistics to simply take a 'cookie cutter' approach - that is, collect data, run basic tests on it and call it a day. Sadly this is common even at our level, and you will almost certainly see this happen at music psychology conferences that you go to in future. People will present complex analyses that sound impressive - until you pick up on small cues that suggest they don't really understand their data at all.

Below is an example of why data visualisation should be a crucial part of the quantitative research process:

#box(image("img/datasaurus.gif"))

This series of datasets is called the #link("https://www.research.autodesk.com/publications/same-stats-different-graphs/")[Datasaurus Dozen], which are 12 datasets that look entirely different (including the dinosaur!) but share almost identical summary statistics, as shown by the bold numbers on the right.#footnote[There is actually an R package of the Datasaurus Dozen that you can play with: https:\/\/cran.r-project.org/web/packages/datasauRus/vignettes/Datasaurus.html]

Data visualisation is important because:

+ It lets you #strong[observe patterns in your data].
+ It can #strong[reveal unexpected structures in your data] that would normally be missed otherwise.
+ It is an effective way of #strong[communicating information]. The best graphs tell a reader everything they need to know in one image.

In the Canvas version of this subject, there are some general guidelines as to how to make good figures right around this point. For this version of the book, the #link(<ggplot>)[section on ggplot] is going to be infinitely better.

Regardless of which graph you use, every good graph should have the basic following features:

Content made with H5P.

== Counts and central tendencies
<basic-desc>
#block(fill: rgb("#f5f5f5"))[
Once we understand what our data looks like, we can then move to describing the general properties of the data. Such general properties are called #strong[descriptive statistics]. Reporting descriptive statistics is crucial for many aspects of quantitative research.

]
=== Basic features
<count-basics>
There are a couple of basic features of any dataset that should be looked at and noted:

#table(
  columns: (7.93%, 39.21%, 52.86%),
  align: (left,left,left,),
  table.header([Name (APA Symbol)], [Definition], [When to report?],),
  table.hline(),
  [Count (n)], [The number of data points.], [The number of participants should always be reported - not just for the sample as a whole, but for each analysis done.],
  [Range], [In the context of writing up statistics, this is usually the minimum and maximum values.], [Reporting these values is often useful as a range when writing up demographic variables, e.g.~age or years of training.],
  [Percentages], [], [Use primarily for categorical data, e.g.~sex or groups.],
)
We can use R to find some of these values, either using straight base R or tidyverse functions. For this page/module only, I will use the #NormalTok("variable_a"); mock variable from #link(<vectors>)[Section 2.2.2] with a minor amendment:

#block[
#Skylighting(([#NormalTok("vector_a ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("4");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("6");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok(")");],
[#NormalTok("vector_a");],));
#block[
#Skylighting(([#NormalTok("[1] 4 1 6 2 3 4");],));
]
]
For tidyverse usage, I'll refer to #NormalTok("df_a");, which is just the same but as a one-column dataframe:

#block[
#Skylighting(([#NormalTok("df_a");],));
#block[
#Skylighting(([#NormalTok("  column_a");],
[#NormalTok("1        4");],
[#NormalTok("2        1");],
[#NormalTok("3        6");],
[#NormalTok("4        2");],
[#NormalTok("5        3");],
[#NormalTok("6        4");],));
]
]
To find the #emph[count], or the number of items in a vector, we can use the #NormalTok("length()"); function.

#block[
#Skylighting(([#FunctionTok("length");#NormalTok("(vector_a)");],));
#block[
#Skylighting(([#NormalTok("[1] 6");],));
]
]
To find the minimum and maximum, we can use the #NormalTok("min()"); and #NormalTok("max()"); functions respectively. Specifying #NormalTok("na.rm = TRUE"); will remove any missing data before calculation.

#block[
#Skylighting(([#FunctionTok("min");#NormalTok("(vector_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 1");],));
]
#Skylighting(([#FunctionTok("max");#NormalTok("(vector_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 6");],));
]
]
In tidyverse fashion, we can wrap this all in #NormalTok("summarise()"); as follows:

#block[
#Skylighting(([#NormalTok("df_a ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("n =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("min =");#NormalTok(" ");#FunctionTok("min");#NormalTok("(column_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("max =");#NormalTok(" ");#FunctionTok("max");#NormalTok("(column_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok("  n min max");],
[#NormalTok("1 6   1   6");],));
]
]
Note here that rather than using #NormalTok("length()");, we use a function called #NormalTok("n()");. This function only works within #NormalTok("summarise()"); and #NormalTok("mutate()");, but is essentially shorthand for #NormalTok("length()");.

=== Central tendencies
<central-tendency>
While the range can be informative in some sitautions, it usually isn't enough to draw deeper interpretations from raw data. One key way of describing data is in terms of #strong[central tendency] - or where the 'average' value approximately is. There are three main types of central tendency, summarized in the table below.

#table(
  columns: (8.91%, 30.2%, 20.79%, 40.1%),
  align: (left,left,left,left,),
  table.header([Name (APA Symbol)], [Definition], [When to use?], [Things to note],),
  table.hline(),
  [Mean (M)], [The sum of all values, divided by the number of data points.], [Use if data is normally distributed.], [Can be influenced by outliers, so generally unsuitable when data is skewed.],
  [Median (Mdn)], [The 'middle' data point, when sorted in order.], [Use for skewed data, or for ordinal data.], [Generally is less preferable to the mean, except for use in skewed/ordinal data.],
  [Mode], [The most frequent value.], [Use for nominal data.], [Unsuitable for most other types of data.],
)
To calculate a mean and median, use the #NormalTok("mean()"); and #NormalTok("median()"); functions respectively. Both functions also take the #NormalTok("na.rm"); argument.

#block[
#Skylighting(([#FunctionTok("mean");#NormalTok("(vector_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 3.333333");],));
]
#Skylighting(([#FunctionTok("median");#NormalTok("(vector_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 3.5");],));
]
]
#block[
#Skylighting(([#CommentTok("# Using summarise() and piping");],
[],
[#NormalTok("df_a ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("mean =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(column_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("median =");#NormalTok(" ");#FunctionTok("median");#NormalTok("(column_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok("      mean median");],
[#NormalTok("1 3.333333    3.5");],));
]
]
Interestingly, R doesn't offer a base function to calculate a mode - if you need this information, you either need to manually work this out or turn to a package that offers it. One such example is the fantastic #NormalTok("DescTools"); package, which provides a function called #NormalTok("Mode()");:

#block[
#Skylighting(([#NormalTok("DescTools");#SpecialCharTok("::");#FunctionTok("Mode");#NormalTok("(vector_a)");],));
#block[
#Skylighting(([#NormalTok("[1] 4");],
[#NormalTok("attr(,\"freq\")");],
[#NormalTok("[1] 2");],));
]
]
The first number is the value of the mode, while the second number is the number of times the mode occurs (twice, in this case).

== Variability
<variability>
#block(fill: rgb("#f5f5f5"))[
The other important part of describing data is in how spread out it is. Is our data tightly bunched together, or is it very spread out? This helps us understand where most of our data falls, as well as how it looks.

]
=== The variability of data
<the-variability-of-data>
The other key way of describing data is in its #strong[spread,] or distribution. The way data is distributed can give key insights into how that data should be treated.

Consider the following graphs below.

#align(center)[#box(image("02-descriptives_files/figure-typst/unnamed-chunk-15-1.svg"))]
You can see that all three graphs peak at around the same point, but #emph[look] very different outside of that. The orange line is narrow, while the red line is considerably more spread out. All of these graphs peak at the same point but still look very different. Therefore, they have very different #strong[spreads], or #strong[distributions].

We saw on the last page that we can quantify how far values are spread apart by finding the range. However, this isn't always a good idea - two datasets with the exact same range can look wildly different. Therefore, we need ways of quantifying how data is spread out as well.

=== Percentiles, and the IQR
<percentiles-and-the-iqr>
A basic way of describing variability in our dataset is by reporting #strong[percentiles] or quantiles of the data. This is simply reporting what values fall within a certain percentage of the range of the data. For example, the 20th percentile captures all data that is in the bottom 20% of the sample.

Consider the following basic dataset:

#block[
#Skylighting(([#NormalTok("dataset_a ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("7");#NormalTok(", ");#DecValTok("10");#NormalTok(", ");#DecValTok("8");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("6");#NormalTok(", ");#DecValTok("5");#NormalTok(", ");#DecValTok("9");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("0");#NormalTok(", ");#DecValTok("8");#NormalTok(", ");#DecValTok("8");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("9");#NormalTok(", ");#DecValTok("7");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("5");#NormalTok(")");],
[],
[#NormalTok("dataset_a");],));
#block[
#Skylighting(([#NormalTok(" [1]  7 10  8  1  6  5  9  3  3  4  3  0  8  8  4  9  7  1  1  5");],));
]
]
You can use the #NormalTok("quantile()"); function to get R to calculate percentiles for you. #NormalTok("quantile()"); needs the name of a vector as the first argument, and the desired percentile as a decimal for the #NormalTok("prob"); argument (e.g.~20% = 0.2).

We can, for instance, make the following statements:

- The 25th percentile is the value 3 (count five values from the left - this is 25% of the data).
- The median is 5 (the middle 2 values are 5), which is also the 50th percentile
- The 90th percentile is 9.

#block[
#Skylighting(([#FunctionTok("quantile");#NormalTok("(dataset_a, ");#AttributeTok("prob =");#NormalTok(" ");#FloatTok("0.25");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("25% ");],
[#NormalTok("  3 ");],));
]
#Skylighting(([#FunctionTok("quantile");#NormalTok("(dataset_a, ");#AttributeTok("prob =");#NormalTok(" ");#FloatTok("0.50");#NormalTok(") ");#CommentTok("# You could also use median(dataset_a)");],));
#block[
#Skylighting(([#NormalTok("50% ");],
[#NormalTok("  5 ");],));
]
#Skylighting(([#FunctionTok("quantile");#NormalTok("(dataset_a, ");#AttributeTok("prob =");#NormalTok(" ");#FloatTok("0.90");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("90% ");],
[#NormalTok("  9 ");],));
]
]
#NormalTok("quantile()"); can return multiple percentiles by giving a vector of decimals to the #NormalTok("prob"); argument. For an IQR, we can tell R to calculate percentiles for the vector #NormalTok("c(0.25, 0.75)"); - representing the 25th and 75th percentiles:

#block[
#Skylighting(([#FunctionTok("quantile");#NormalTok("(dataset_a, ");#AttributeTok("prob =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#FloatTok("0.25");#NormalTok(", ");#FloatTok("0.75");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("25% 75% ");],
[#NormalTok("  3   8 ");],));
]
]
A specific form of this that can be quite useful is the #strong[interquartile range (IQR)], which describes the #strong[middle 50%] of the data (i.e.~25% either side of the median). It is a single value that represents the 75th percentile score #emph[minus] the 25th percentile score.

If a dataset is heavily skewed, for instance, reporting the median with the IQR can be a useful way of more accurately capturing the basic features of the data. In this instance, the IQR would be 8 - 3 = 5. You can use the #NormalTok("IQR()"); function to calculate this too (note the #NormalTok("na.rm = TRUE)");).

#block[
#Skylighting(([#FunctionTok("IQR");#NormalTok("(dataset_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 5");],));
]
]
=== Standard deviation
<sd>
#strong[Standard deviation] ($sigma$, or #strong[SD]) describes how spread out our data is within our sample, in standard (i.e.~comparable) units. Data that is spread out widely (like the red curve above) will have a large standard deviation; likewise, data that has a narrow spread will have a small standard deviation. We'll touch on this a bit more in the following pages, but for now just remember what a standard deviation is for.

To calculate standard deviation, we first calculate #strong[variance], which is another measure of spread:

$ V a r i a n c e = frac(Sigma \( x_i - macron(x) \)^2, n - 1) $

Or, in human terms:

- Take each data point ($x_i$)
- Subtract the mean from each data point (x with the bar) and square that difference
- Add them all up together
- Divide by $n - 1$

And then to calculate standard deviation, we simply take the square root of the variance.

$ S D = sqrt(V a r i a n c e) $ Or, in full formula form:

$ S D = sqrt(frac(Sigma \( x_i - macron(x) \)^2, n - 1)) $

Standard deviations (SD) should reported alongside means when results are written up (consult an APA guide).

To calculate standard deviations in R, use the #NormalTok("sd()"); function. Once again, this has an #NormalTok("na.rm"); argument you can specify.

#block[
#Skylighting(([#FunctionTok("sd");#NormalTok("(vector_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 1.75119");],));
]
#Skylighting(([#CommentTok("# Tidyverse form");],
[#NormalTok("df_a ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("sd =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(column_a, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok("       sd");],
[#NormalTok("1 1.75119");],));
]
]
== Distributions
<distributions>
#block(fill: rgb("#f5f5f5"))[
The 'shape' of our data is equally important. What does our data actually look like? Does it even matter what it looks like? The topic of distributions in statistics and probability can make up its own subject (in fact it does), but here we discuss the basics below.

]
=== The normal distribution
<normal-dist>
Earlier, we saw a series of graphs overlaid on top of each other. These graphs, while having different #strong[variability], were essentially all the same #strong[shape] - they were symmetrical bell curves. These were all examples of the #strong[normal distribution] (also called the #strong[Gaussian distribution]). The classic normal distribution takes on a neat bell-shaped curve:

#align(center)[#box(image("02-descriptives_files/figure-typst/unnamed-chunk-21-1.svg"))]
In the normal distribution, the majority of data points cluster in the middle, while all other values are symmetrically distributed from either side from the middle. This is what gives the normal distribution its recognisable bell shape.

The normal distribution is defined by two parameters: the #strong[mean] and the #strong[standard deviation] of the data. These two parameters define the overall shape of the bell curve - the mean defines where the peak is, while the standard deviation defines how spread out the tails are.

An important feature of the normal distribution is where all of the data is spread, regardless of its shape: #strong[95% of the data within the curve] falls within #strong[1.96 standard deviations, either side of the mean]. This applies to any normal distribution no matter what the scale of the data is. 99.7% of data falls within just below 3 standard deviations.

#align(center)[#box(image("02-descriptives_files/figure-typst/unnamed-chunk-22-1.svg"))]
=== Graphing distributions
<graphing-distributions>
The slides below demonstrate a couple of ways in which you can graph distributions.

=== Skew
<skew>
#strong[Skewness], as the name implies, describes whether or not a distribution is symmetrical or skewed. If a distribution is skewed, we would expect numbers to be bunched up at one end of the distribution. Have a look at the three graphs below:

#align(center)[#box(image("02-descriptives_files/figure-typst/unnamed-chunk-23-1.svg"))]
- The purple graph in the middle is symmetrically distributed, so we say that it has no skew.
- The red graph has values that are weighted towards the right-hand side of the x-axis, and so we say that it is either #strong[skewed left] or #strong[negatively skewed].
- The blue graph, on the other hand is #strong[skewed right] or #strong[positively skewed]. The left-right refers to which end the tail of the distribution is on.

Skewness can also be quantified numerically:

- A skewness of 0 means that a distribution is normal
- A positive skew value means that the data is skewed right
- A negative skew value means that the data is skewed left

As a general rule, if a distribution has a skew greater than +1 or lower than -1, it is skewed. If your data is skewed then this is not the end of the world; it depends on the analysis you are performing, or what you are trying to do with the data. We will touch on this a bit more in coming weeks.

=== Kurtosis
<kurtosis>
#strong[Kurtosis] refers to the shape of the tails specifically. Are all of the data bunched very tightly around one value, or are the data evenly spread out? The three graphs you saw up above all have different kurtoses.

#align(center)[#box(image("02-descriptives_files/figure-typst/unnamed-chunk-24-1.svg"))]
The orange graph has most values very close to the peak at 50; therefore, the tails themselves are very small. The red line, on the other hand, is spread out and flatter so the tails are larger. The blue curve again approximates a normal distribution. We can quantify kurtosis through the idea of excess kurtosis - in other words, how far does it deviate from what we see in a normal distribution. This is shown below:

The different types of excess kurtoses are:

- #strong[Leptokurtic (heavy-tailed)] - tails are smaller. Kurtosis \> 1
- #strong[Mesokurtic - normally distributed]. Kurtosis is close to 0
- #strong[Platykurtic (short-tailed)] - tails are larger, and the peak is flatter. Kurtosis \< -1

Therefore, in the example above the orange curve would be considered leptokurtic, while the red one would be platykurtic.

Below are a series of skewness and kurtosis values from three different data sets. For each:

- Determine if the data is skewed or not, and if so then what type of skew
- Determine the type of kurtosis
- Sketch a rough version of what this skew and kurtosis might look like (doesn't have to be perfect!)

#table(
  columns: 4,
  align: (left,right,right,right,),
  table.header([], [Dataset A], [Dataset B], [Dataset C],),
  table.hline(),
  [Skewness], [0.3209], [5.2934], [-3.1945],
  [Kurtosis], [-0.1023], [10.9238], [-2.7263],
)
== Central Limit Theorem
<clt>
#block(fill: rgb("#f5f5f5"))[
In Module 6, we will cover the foundations of statistical tests. However, in order to understand what those tests tell us and how useful they are, it is important to basically look at what allows them to work in the first place. In comes the #strong[Central Limit Theorem], one of the most important concepts in all of statistics. We will also look at #strong[standard error], as this becomes a crucial concept for the next module!

]
=== The sampling distribution of the mean
<sderr>
Imagine that I have a population of 100 regular people (shown on the left). I take a sample of 10 people, measure their heights and then calculate the mean height of that one sample. I then repeat this process over and over again, and plot where each sample's mean falls. Of course, because every sample is slightly different the mean of each sample will be slightly different too due to #strong[sampling error]. Some sample means will be lower than the true population mean, while some will be higher. Eventually, we might end up with something like the spread on the right:

#box(image("img/w5_sdotm.svg"))

The spread of these sample means is called the #strong[sampling distribution of the mean (SDoTM)], shown on the right.

=== The Central Limit Theorem
<the-central-limit-theorem>
The hypothetical height example above demonstrates the #strong[Central Limit Theorem (CLT)], a fundamental theorem of probability theory. It states that under the right conditions, the #strong[sampling distribution of the mean will converge to a normal distribution]. This occurs even when the original data are #emph[not] normally distributed.

The Central Limit Theorem works on the #strong[law of large numbers], another fundamental probability theory. The law of large numbers states that given a large enough sample, our estimates of a probability or phenomenon should converge on the #emph[true] value. For example, consider a regular six-sided die. If the die is fair, each possible #emph[outcome] or number should have a 1/6 chance of being rolled. Therefore, if we were to roll a single die 100,000 times then we should see that 1 in 6 chance (16.67%) bear out in the data:

#box(image("02-descriptives_files/figure-typst/unnamed-chunk-27-1.svg"))

The CLT utilises the same principle. If we conduct studies with large enough samples then our estimates of a parameter should converge (or at least get pretty close) to the #emph[true] population value.

A general rule of thumb for sample sizes is that #strong[n \> 30] is sufficient even when the population is skewed. In other words, even if a population is heavily skewed on a variable, taking several samples of n \> 30 will still show a normally distributed set of sample means. You can see this for yourself in the simulator above - try set sample size to 5, 10 and then 30, and see what happens in the Sampling Distribution tab.

=== Standard error of the mean
<standard-error-of-the-mean>
Coming back to the height example above, we can see that the sampling distribution on the right resembles the actual distribution on the left pretty closely. This is a good thing! This gives us a sense of where the #strong[population mean] (the parameter that we are interested in) might lie. With enough samples, the peak of this sampling distribution of the mean will converge around the population mean. As you can see in our hypothetical example, the peak of the sampling distribution of the mean sits pretty close to the original population mean, meaning our estimate is pretty good.

However, of course, in a real research setting we typically do not take multiple repeated samples like this, and instead just take one. Thanks to the CLT, though, we know that if our sample is large enough, we should still be converging closer to the true mean than we would if we had a small sample. This still allows us to make inferences about the population parameter with just one sample.

The #strong[standard error of the mean] (standard error; SE) is another measure of variability - this time, it is the spread of #strong[sample means] across the sampling distribution of the mean. This represents how close our sample mean is to the likely #emph[population] mean, and therefore is one way of estimating the #emph[precision] of our effect. If our sampling distribution is wide, our standard error will be large - and that means that we won't have a very precise estimate of the population mean. However, if we have a small standard error that will mean that our sample mean is likely to be close to the population mean.

Standard error is calculated using the below formula:

$ S E = frac(S D, sqrt(n)) $

Where SD = standard deviation, and n = sample size.

Based on the formula alone, hopefully one critical element is clear: with bigger samples, the standard error decreases - and therefore, the sample mean should be closer to the population mean. This means that with large samples, we should ideally be getting a really good estimate of the population of interest! Conversely, smaller sample sizes (as is common in music research) are unlikely to be good estimates of populations due to the inherently greater amount of error involved. Therefore, we should always be aiming for #strong[larger sample sizes] wherever possible for statistical analyses.

=== Simulation
<simulation>
To test this for yourself, try the below sample simulator. You can set what distribution you want to draw from, and choose how many samples and simulations you want to run.

The Population Distribution tab will show you what you are sampling from; the Samples tab is each individual sample and the Sampling Distribution tab shows the distribution of sample means. Try and change the sample size and see how that impacts on the Sampling Distribution.

\(You may need to scroll within the app to see the full output.)

#block[
]
== z-scores
<zscores>
#block(fill: rgb("#f5f5f5"))[
The last major component of this week is about a really useful but important property of the normal distribution (which, as you may have guessed, is fairly important in statistics. The process of #strong[standardising] data and calculating #strong[z-scores] is one that we actually use a lot in statistics.

]
Let's briefly recap where we're at so far:

- We've covered basic descriptive statistics, such as means, standard deviations etc etc.
- We've talked a bit about the normal distribution and its properties - specifically, that 95% of your data lies within 1.96 SD either way of the mean

If you've got those concepts down, the rest of this page will be fairly straightforward.

=== z-scores
<z-scores>
#strong[z-scores] (z), sometimes called #strong[standard scores], are a measure that describe how many standard deviations a single data point is from the mean. If you recall the figure of the normal distribution from the previous page, notice how we quantify how much data is captured in terms of the number of standard deviations. z-scores are essentially this number - in other words, 95% of your data lies between z = -1.96 and z = 1.96.

#box(image("02-descriptives_files/figure-typst/unnamed-chunk-29-1.svg"))

The process of calculating z-scores is called standardisation. The primary utility of converting data into z-scores is that it becomes possible to compare data on different scales. Many statistical analyses employ some form of standardisation for a variety of reasons - some of which we'll see in this subject.

=== Calculating z-scores
<calculating-z-scores>
The formula for converting a raw data point into a z-score is:

$ z = frac(x - mu, sigma) $

Where x = an individual data point, $mu$ = mean and $sigma$ = SD.

For example - in their paper on the Goldsmiths Musical Sophistication Index, Mullensiefen et al.~(2014) show that their general sophistication measure has a mean of 81.58, with an SD of 20.62. If a participant scores 100, we can calculate a z-score to see how many standard deviations they are away from the mean:

$ z = frac(100 - 81.58, 20.62) $ $ z = 0.8933 $ A participant with a general sophistication score of 100 would be roughly 0.89 standard deviations away from the mean.

To z-score a vector in R, we use the #NormalTok("scale()"); function. The #NormalTok("scale()"); function takes two arguments: #NormalTok("center");, which determines whether the data is centered (i.e.~subtracts the mean from each value), and #NormalTok("scale");, which essentially scales the data so the SD is 1. By default, both of these arguments are true.

#block[
#Skylighting(([#FunctionTok("scale");#NormalTok("(vector_a)");],));
#block[
#Skylighting(([#NormalTok("           [,1]");],
[#NormalTok("[1,]  0.3806935");],
[#NormalTok("[2,] -1.3324272");],
[#NormalTok("[3,]  1.5227740");],
[#NormalTok("[4,] -0.7613870");],
[#NormalTok("[5,] -0.1903467");],
[#NormalTok("[6,]  0.3806935");],
[#NormalTok("attr(,\"scaled:center\")");],
[#NormalTok("[1] 3.333333");],
[#NormalTok("attr(,\"scaled:scale\")");],
[#NormalTok("[1] 1.75119");],));
]
]
=== Comparing across scales
<comparing-across-scales>
As mentioned above, we can use z-scores to compare across measures on different scales. This becomes really useful when we want to compare two participants, for instance, or two different measures. This is simply done by calculating a z-score for each formula - as long as you know the mean and standard deviation of each scale as well.

As a simplistic example, let's say we have two scales:

- Measure A sits on a scale of 0 - 100, with a mean of 50 and a standard deviation of 5
- Measure B sits on a scale of 0 - 80, with a mean of 45 and a standard deviation of 4

If a participant scores 40 on both scales, clearly we can't compare them directly - a 40/100 is vastly different to a 40/80! But we could convert these into z-scores to see where the participant sits on each scale:

$z_a = frac(40 - 50, 5)$, and $z_b = frac(40 - 50, 5)$

$z_a = frac(- 10, 5)$, and $z_b = frac(- 5, 4)$

$z_a = - 2 \, z_b = - 1.25$

In other words, the participant's z-score on Measure A is -2, and -1.25 on Measure B. Based on this, we can say that the participant scored slightly higher (relatively) on Measure B compared to Measure A.

A z-score lets us see how many standard deviations away from the mean a participant is. However, a more intuitive way of thinking about this is what percentile they sit in. To do this, we use something called a z-table. This z-table, in short, allows us to work out this percentage.

Most versions of the z-tables will present two separate z-tables: one for negative z-values, and one for positive z-values (credit: #link("https://zoebeesley.com/2018/11/13/z-table/"))

#box(image("img/z-table.webp"))

Here are the steps to read this table:

+ Choose which table to read first. If you have a negative z-score, read the left one; if you have a positive z-score, read the right one.
+ The rows and columns are basically arranged by #strong[decimal place]. The rows index z-scores to 1dp, while the columns add the second decimal place. So, find the #strong[row] first that corresponds to your z-score. In our example from above, our z-score was 0.89, so we want to find the row corresponding to 0.8.
+ Next, find the column that corresponds to the second decimal place. We want to go all the way to the right-hand column labelled #strong[.09], to find the right column for our z-score of 0.89.
+ Find the cell that corresponds to the row and column from above - that is the probability of getting a value #strong[below] our z-score.

#align(center)[#box(image("img/ztable_highlight.png"))]
In this instance, our z-score of 0.89 has an associated probability of .8133, meaning that 81.3% of scores are below this z-score.

R, however, has a way of finding probabilities (percentiles) for z-scores for you. The #NormalTok("pnorm()"); function calculates the probability of a specified value on a normal distribution. Given that z-scores follow the normal distribution, we can use #NormalTok("pnorm()"); to calculate a given z-score's associated probability.

The function is simple: it requires you to give the z-score (as argument #NormalTok("q");), the mean and standard deviation of the normal distribution you are interested in. By default, the mean is set to 0 and the SD set to 1, which is what we want for a z-score.

#block[
#Skylighting(([#FunctionTok("pnorm");#NormalTok("(");#FloatTok("0.89");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 0.8132671");],));
]
]
= Inferential statistics
<inferential-statistics>
From a conceptual point of view, this week's module might just be the most important that we cover in this subject. I don't say that to freak you out, but in many ways it just is the genuine truth. The reason that this might be the most important one is because the topics that we cover in this module are ones that many people frequently misunderstand or misappropriate - to the point of scientific fraud.

Inferential statistics are the subject of very heated debate in statistics, primarily about whether p-values and the like are really the right way to do science and statistics. We won't really go there because that's neither here nor there in terms of what the aim of this module really is: to not only show you one way of hypothesis testing, but to also equip you with the knowledge needed to understand how other people test hypotheses - or, sometimes, fail to do so.

Before you go into this module - make sure that you have 5.4 Variability, 5.5 Distributions and 5.6 Central Limit Theorem firmly under your belt as they will be relevant here.

By the end of this module you should be able to:

- Describe the steps taken to test a statistical null and alternative hypothesis
- Correctly define a p-value
- Explain the difference between Type I and Type II error, and how these relate to statistical power
- Construct a basic confidence interval for a point estimate, and interpret it

#figure([
#box(image("index_files\\mediabag\\null_hypothesis.png"))
], caption: figure.caption(
position: bottom, 
[
#link("https://xkcd.com/892/")[xkcd: Null Hypothesis]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


== The logic of hypothesis testing
<the-logic-of-hypothesis-testing>
#block(fill: rgb("#f5f5f5"))[
Central to all statistical testing is the underlying logic of hypothesis testing. All of the statistical tests that we cover in this module are built on this logic - and so it marks a great place for us to start our venture into inferential statistics.

]
=== Revisiting the hypotheses
<revisiting-the-hypotheses>
In Module 4 on Canvas, you will have had the chance to write your own hypothesis. This hypothesis guides the overall research and methodological design of our studies. However, you may have noticed that the hypotheses discussed in the video are not quite in the same format. This is because 'hypothesis' in this context refers to statistical hypotheses.

Statistical hypotheses are formal statements that we use when testing for an effect. As mentioned in the video above, we propose two contrasting hypotheses when we want to do statistical testing:

- The null hypothesis ($H_0$) - that there is no effect or difference
- The alternative hypothesis ($H_1$) - that there is an effect or difference

We can never know for sure whether one hypothesis is correct over the other. Instead, we choose to either reject or not reject the null hypothesis.

=== The issue of tails
<the-issue-of-tails>
There are two main types of alternative hypotheses:

- Two-tailed: we hypothesise that something is happening regardless of whether it's greater, smaller, increasing, decreasing etc…
- One-tailed: we hypothesise that the effect has a direction

In a two-tailed hypothesis, we predict that an effect is occuring but we don't predict anything beyond that. For example, if we are comparing whether two groups are different our alternative hypothesis would be that they are different - but we don't predict whether group A will be bigger than group B or vice versa. These are sometimes called non-directional hypotheses.

The blue areas on the curve on the right represent a 0.05 level of signifiance for a two-tailed hypothesis test. This is essentially how likely it is that we would observe our effect/difference if nothing was happening. If a difference is large enough that it falls within these blue tails, it is statistically significant. This is because if nothing really was happening, it would be unlikely that we see an effect/difference this big. Therefore, we would choose to reject the null hypothesis at this would fall below our chosen significance level.

#box(image("03-inferential_files/figure-typst/unnamed-chunk-3-1.svg"))

In a one-tailed hypothesis, we predict that the effect exists in a specific direction (hence, they are directional hypotheses). For example, we might predict that Group A is bigger than Group B. Or, we might predict that as X increases, Y increases too.

The two curves below show the significance levels for one-tailed hypotheses. If we predicted that Group A was smaller than Group B, we would only reject the null hypothesis if Group A really was smaller than Group B, and this difference was large enough to be statistically significant (i.e.~within one of the green tails).

#box(image("03-inferential_files/figure-typst/unnamed-chunk-4-1.svg"))

== p-values
<p-values>
#block(fill: rgb("#f5f5f5"))[
At one point, the video on the previous page talks about 'levels of significance' - what does this actually mean? Here, we'll talk about the p-value - one of the most commonly used, and possibly abused, concepts in research and statistics. We'll talk about what the p-value actually means, and tie it to two related concepts later in this module: error and statistical power.

]
=== The definition of the p-value
<the-definition-of-the-p-value>
The definition of the p-value is the following (APA Dictionary, 2018):

#quote(block: true)[
"in statistical significance testing, the likelihood that the observed result would have been obtained if the null hypothesis of no real effect were true."
]

What does this actually mean? We actually already touched on this in the previous page, but let's dig a bit deeper.

=== A brief probability primer, and how this relates to p-values
<a-brief-probability-primer-and-how-this-relates-to-p-values>
To start with, a p-value is a probability. A probability, of course, ranges from 0 to 1; 0 (0%) representing an impossible result, and 1 (100%) representing a certain result. Probabilities can be conditional, meaning that they are dependent on a certain condition being true. A p-value is a conditional probability. Specifically, a p-value refers to the probability of getting a particular result, assuming the null hypothesis. To illustrate what we mean, consider the two graphs below, showing some example data as points.

#box(image("img/null_alt.svg"))

On the right is an example of what one possible alternative hypothesis might look like - that this data is meaningfully represented by two underlying distributions or groups, and that there is a difference between these two groups (shown as the blue and red curves). Contrast that with the left graph, where we hypothesise that there is no difference - in other words, that the data can be captured by the one distribution. This graph on the left is a representation of our null hypothesis, and as per the definition of the p-value, this is the distribution we focus on.

#box(image("img/prob_dist.svg"))

The area shaded blue represents the probability of getting that specific result. In the left example, the area shaded represents the probability of getting a value lower than x = 1. You can see that the blue area is quite big, so the probability of getting a value lower than 1 is quite high. On the right hand side is another example, which represents the probability of getting a value of x higher than 2. Here, the shaded area is small, so the associated probability is low.

Now, recall the following figure from last week:

#align(center)[#box(image("03-inferential_files/figure-typst/unnamed-chunk-7-1.svg"))]
We established last week that on a normal distribution, 95% of the data lies within a certain range of values. Obtaining values beyond these thresholds (1.96 standard deviations either side of the mean) account for a relatively small percentage of possible values. In other words, the probability of getting a value beyond these bounds (in the figure above, where the dark green areas are) #strong[is low].

This is basically the thinking we use when we calculate a p-value. Let's break down the steps:

+ We first #strong[assume the null hypothesis is true], and so we use the distribution of the null hypothesis to calculate the probability of getting our result or greater.
+ To figure out where our result(s) sits on this null distribution, we calculate a #strong[test statistic]. This test statistic is essentially a value that represents where our data sits on the test (null) distribution. Each test statistic is calculated in a different way because every distribution looks different, so we'll come back to this over the next couple of weeks.
+ Afterwards, we calculate the probability of getting our test statistic (or greater) using a similar logic to the example above. This probability is our p-value. This marks the probability of observing this result or greater.
+ Once we have a p-value we then compare this against #strong[alpha], which is our chosen significance level (usually p = .05). If the probability of getting our result is smaller than this (pre-defined) cutoff, it means that it is unlikely assuming the null hypothesis is true, and therefore our result is statistically significant and we #strong[reject the null hypothesis. ]

So in essence, if a p-value is p = .05 we're saying that assuming the null is true, there is a 5% chance of observing this result or greater. Likewise, an extremely small p-value (e.g.~p = .0000000001) means that assuming the null is true, the probability of getting the data we have is extremely small. The logic, therefore, is that there must be an alternative explanation.

To clarify, the example above is just on a normal distribution - each statistical test we perform has its own (null) distribution, which we will talk about more in future modules. However, the rationale across tests is essentially the same.

#block[
#callout(
body: 
[
Throughout history, p-values have been so misunderstood and misappropriated that some journals, such as Basic and Applied Social Psychology, actually either discourage or outright ban the reporting of p-values. This ties into a wider debate about the usefulness or meaningfulness of the hypothesis testing approach outlined on the previous page, with a number of academics and scientists arguing that it is time to do away with the system as a whole.

The debate is something that goes beyond the scope of the subject, so we won't be taking a strong stand on it either way. What we do think though is that it's really important that you understand how hypothesis testing works and what p-values can or can't tell you.

]
, 
title: 
[
The debate around p-values
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Types of error
<types-of-error>
#block(fill: rgb("#f5f5f5"))[
Nothing in life is perfect, and that applies to the inferential statistics that we do. Every sample will differ slightly from one to another due to inherent sampling error; in a similar way, whenever we do an inferential test about a population from a sample, we always run the risk of making an error in the decisions that we make.

]
=== Statistical error
<statistical-error>
Imagine an old man is seeing his local GP complaining of a headache. Upon examination, the doctor concludes that the old man is pregnant.

A pregnant woman in her last trimester then comes in to the same GP. Despite her numerous pregnancy-related complaints, the doctor concludes that she is not pregnant.

Both of these scenarios (while hopefully very unlikely!) are obviously forms of errors on the doctor's part. In the first scenario, the doctor has accepted a diagnosis that is very clearly wrong. In the second scenario, the doctor has rejected the correct diagnosis.

The same kind of logic applies directly to quantitative research. We want to be sure that when we observe a result, that result is actually likely. We therefore want to minimise the possibility of errors like above.

We can draw a table to illustrate the possible outcomes when we perform a given hypothesis test:

#table(
  columns: (31.58%, 34.21%, 34.21%),
  align: (left,left,left,),
  table.header([], [Accept the null], [Reject the null],),
  table.hline(),
  [The null is true], [Correctly accept the null], [Type I error],
  [The alternative is true], [Type II error], [Correctly reject the null],
)
=== Type I error and alpha
<type-i-error-and-alpha>
A moment ago we talked about alpha ($alpha$), or the significance level, from the previous sections about hypothesis testing and the p-value. Alpha is the same here as it is there - it is the probability of making a Type I error - that we incorrectly reject the null hypothesis when the null hypothesis is actually true. Essentially, alpha is the rate of Type I error we're willing to accept whenever we do a hypothesis test.

We generally set alpha as #emph[p] \< .05 out of convention - i.e.~most of the time, we're willing to accept a 5% chance of a Type I error rate. However, we can set alpha to anything we want. Sometimes, we may set it lower (more on this in a few weeks' time).

== Statistical power
<statistical-power>
#block(fill: rgb("#f5f5f5"))[
Another related but crucial consideration for inferential statistics is the concept of statistical power. Without spoiling too much about what it means here, below is an overview of what this concept is and why it is important.

]
=== Statistical power
<statistical-power-1>
Power in a statistical context essentially describes how likely we are to actually detect an effect given our sample size. Mathematically, power is defined as $1 - beta$, which in English terms means that it is the probability of not making a Type II error. Power is expressed as a percentage. For example, if your study has 50% power, it means it has an 50% chance of actually detecting an effect. The most common guideline is to aim for a study with 80% power.

=== Factors that affect power
<factors-that-affect-power>
The primary factor (within your control) that affects how much statistical power you have to detect an effect is sample size. Think back to the formula for standard error, as a proxy explanation as to why this is the case. Larger samples tighten the sampling distribution of the mean, and so two distributions will overlap less and less the greater the sample sizes are. Therefore, if there is less overlap there is greater space to detect an effect.

Some other factors that can affect power are:

- The effect size - how large is the difference between your groups, etc? If you're trying to detect very small effects, you need much more power to detect it compared to larger ones.
- Performing a one-tailed test - because effects are only being tested in one direction, this alters the p-value (it actually halves it; a two-tailed p = .10 is a one-tailed p = .05). Don't do this though, because there are very few instances in which you can justify using a one-tailed test without reviewers and other clued-in readers suspecting that you're intentionally fudging your power.
- Increase alpha - for a semi-detailed explanation of why, see here. In addition, there is a nifty tool here that lets you see what happens to error rates when you change specific parameters: Link to the tool

The consequence of being underpowered means that you can miss effects that exist. A good proportion of studies in psychology are underpowered, meaning that effects are being missed where they exist. Power is therefore an integral consideration of good study design, particularly for experimental contexts.

=== Power analyses
<power-analyses>
Identifying an appropriate level of statistical power is an important part of planning quantitative research. Before conducting a study, it is wise to run a power analysis. Doing a power analysis allows you to identify how many participants you may need in order to reliably detect an effect of a given size.

Most modern statistics software will allow you to conduct power analyses:

- SPSS (from version 27)
- Jamovi (with the jpower module)
- R (with the #NormalTok("pwr"); package, among many others)

We won't get too into the maths here of how this is done (it heavily depends on your research design, e.g.~how many groups you have, what test you plan on doing…). These programs will let you select the appropriate design you want to test, and choose the size of the effect you want and your alpha level. The power analysis will then give you a minimum sample size per group for you to achieve that level of statistical power.

#block[
#callout(
body: 
[
You might see authors in some papers where you present a power analysis after collecting your sample and doing your analyses. Supposedly, this is to show that your sample had enough power to detect an effect. However, this is conceptually flawed. The primary flaw is that post-hocs are essentially just restatements of your p-values and so do little to show the true power of a design/test.

]
, 
title: 
[
Post-hoc power analyses
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
== Confidence intervals
<confidence-intervals>
#block(fill: rgb("#f5f5f5"))[
As we saw on the page about p-values, some people are vocal about their distaste for relying solely on p-values for decision making. One way of augmenting our estimates is to calculate a confidence interval for each estimate we make. Confidence intervals provide an estimate of the precision of our estimate, and so are a crucial concept to know about.

]
=== A reminder from the previous module
<a-reminder-from-the-previous-module>
It's time to force you to remember what the graph below means once again (I promise this is the last time you will see this figure! I think). By now you should be very familiar with what this graph shows; namely, that 95% of the data in a normal distribution lies within 1.96 standard deviations either side of the mean, yada yada.

#align(center)[#box(image("03-inferential_files/figure-typst/unnamed-chunk-9-1.svg"))]
This sounds all well and good, but this provides us with some useful information. If all that business about values within 1.96 standard deviations is still fresh in your mind, this next statement should be a no-brainer: if 95% of our data on a normal distribution lies within 1.96 SD either side of the mean, that means that there is a certain range of values that 95% of our data falls in.

For example, say we have a sample of scores on a test, with a mean of 70 and a standard deviation of 4. If we want to know where 95% of the scores lie in this sample, we would do the following calculation:

$ 95 % med r a n g e = M plus.minus \( 1.96 * S D \) $

Using this formula, we can calculate the values where 95% of the data lie:

$ 95 % med r a n g e = M plus.minus \( 1.96 * S D \) $ $ 70 plus.minus 7.84 $

$ = 62.16 \, 77.84 $ In other words, 95% of our data in this sample lie between 62.16 and 77.84. The remaining 5% of the sample lie above or below these values.

=== Confidence intervals
<confidence-intervals-1>
We can use the same principle to make inferences about the true population parameter. When we take a sample, each one will have its own standard error (remember this reflects an estimate of the distance between the sample mean and the true population mean). If we were to repeatedly take samples, in the long run we would expect the true population mean to fall within 95% of all sample means. And, just like the normal distribution, when we look at the sampling distribution of the means below, 95% of all sample means will fall within 1.96 standard errors (thanks to the Central Limit Theorem).

#align(center)[#box(image("03-inferential_files/figure-typst/unnamed-chunk-10-1.svg"))]
With this important property in mind, we can calculate a 95% confidence interval. This is an estimate of the range of values for our estimate of the parameter. In other words, it is a measure of precision. The formula for a 95% confidence interval, as it turns out, is exactly the same as above with one change:

$ 95 % C I = M plus.minus \( 1.96 times S E \) $

Therefore, if we have an estimate of a population parameter (e.g.~what the population mean is), we can use a 95% CI around that estimate to quantify the precision/uncertainty of that estimate. If a confidence interval is narrow, it suggests our estimate is quite precise.

This can be extremely informative: not only can we use CIs to infer whether an effect is significant or not, but now they quantify #emph[how] precise our estimates are. For example, pretend that we have a null hypothesis that a parameter is equal to 0 (as is usually the case). If we calculate a confidence interval and that happens to include the value of 0 (e.g.~95% CI: \[-0.5, 1.5\]), we can immediately infer that 0 is a likely value for this parameter - and thus, the null hypothesis is plausible. On the other hand, if the CI did not include 0 then we could infer that there likely is a significant effect.

Likewise, a CI of something like \[0.5, 0.8\] compared to a CI of \[0.2, 20.5\] tells us that the former is a much more precise of a parameter estimate than the latter.

Not all confidence intervals though will contain the true parameter purely because of how samples work (i.e.~the inherent error between a sample and a population). In addition, it does not mean that there is a 95% chance a single interval will contain the true parameter. So what does the 95% part refer to?

=== Confidence
<confidence>
The confidence level is a long-run probability that a group of confidence intervals will contain the true population parameter. A 95% confidence level means that if we were to take samples repeatedly and calculate a CI for each one, 95% of those CIs will contain the true population parameter in the long-run.

Or, say if you were to take 100 samples and calculate a CI for each one, 95 of them would include the true population parameter:

#box(image("03-inferential_files/figure-typst/unnamed-chunk-12-1.svg"))

The 95% long-run probability #strong[does not change] with sample size. What does change, however, is the #strong[precision] of the estimates. This makes sense if you remember the formula for standard error, which divides by the square root of #emph[n]. A larger #emph[n] will lead to lower SE, and thus narrower confidence intervals. Below is an example with a much larger sample size. Notice how the confidence intervals are now much smaller:

#box(image("03-inferential_files/figure-typst/unnamed-chunk-13-1.svg"))

The choice of 95% is conventional, like alpha (our significance criterion); we can (but often don't) change our level of confidence. This changes the relevant formula for calculating the interval, as in the examples below:

$ 90 % med C I = M plus.minus \( 1.645 times S E \) $

$ 99 % med C I = M plus.minus \( 2.576 times S E \) $

Notice that the value we multiply the SE by has changed. If you have been especially observant so far, you may have figured out what these values are: they're z-scores!

#block[
#callout(
body: 
[
On the page about #emph[p]-values, I left a brief note around some of the current discourse around the usefulness (or uselessness) of #emph[p]-values. Proponents of getting rid of #emph[p]-values/moving away from them advocate strongly for two alternatives: a) effect sizes (self-explanatory; we will come to this) and b) confidence intervals, to show the range of long-run plausible values for the estimate.

Again, we won't be taking an especially strong stance either way. That being said, it is now fairly common practice to report 95% confidence intervals alongside the results of significance tests for transparency. Programs like Jamovi will usually calculate these intervals automatically for you.

]
, 
title: 
[
Confidence intervals in literature
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#part[Part II: Basic inferential tests]
= Chi-squares
<chi-squares>
While many of the things we are interested in when it comes to psychological research are continuously distributed (height, weight, reaction time, personality), there are many instances where we will need to work with data that is categorical. This can involve categorical independent variables (e.g.~assigning participants to one or two groups) or categorical outcomes (e.g.~responding yes or no). We'll start with looking at relationships between these categorical variables, and testing for significant associations.

This module will see you diving deep into Jamovi again - so be prepared to get hands on with a bunch of data! Between the seminar, the worked examples and exercises there are at least 6 different datasets to play around with for this week!

By the end of this module you should be able to:

- Describe how a chi-square statistic is calculated
- Conduct two forms of chi-square tests: goodness-of-fit and tests of independence
- Calculate and interpret an appropriate effect size for tests of independence

#figure([
#box(image("index_files\\mediabag\\question_2x.png"))
], caption: figure.caption(
position: bottom, 
[
#link("https://xkcd.com/1448/")[xkcd: Question]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


== Calculating a chi-square
<calculating-a-chi-square>
#block(fill: rgb("#f5f5f5"))[
We'll start this module off by briefly going through the basics of what research designs suit chi-square tests, as well as the basic maths underlying the first part of the statistical test.

]
=== Categorical data
<categorical-data>
As mentioned at the start of this module, chi-square tests are used when we work with #strong[categorical data] - i.e., when we are dealing with #emph[counts] of items or people, rather than continuous variables. Research questions focused on relationships or associations among categorical variables are suited to chi-square tests.

Every categorical variable will have #strong[levels] (categories) within them. These are the different values that categorical variable can be. For example, biological sex is often coded with two levels: male and female. Or perhaps you might categorise socioeconomic status into three levels: low, medium and high bands. This is something that can form a core part of your research design. The most basic example is asking participants what their biological sex is - participants will respond with one of the two categories.

Alternatively, you can #emph[create] categories from existing data. For example, many scales designed to assess psychological disorders such as depression and anxiety often have 'cutoff' points, where a certain score on the scale is indicative of a possible disorder. If you have everyone's raw scores, you can convert these scores into categories depending on whether they are above or below these cutoff points (though this needs to be strongly justified).

All of this kind of data are amenable to chi-square tests, #emph[if] you are interested in relationships between categorical variables. The family of chi-square tests basically work by comparing the #strong[observed values to] the #strong[expected values]. As the names imply, observed value simply means the number of observations we have in each category or level (i.e.~what our data actually is). Expected values, on the other hand, are the number of things we would #emph[expect] to see under the null hypothesis.

We can visualise categorical variables in two basic ways: a) a #strong[contingency table] or b) a #strong[bar graph of counts]. Below is the same set of data, shown in both forms:

=== The chi-square formula
<the-chi-square-formula>
To test whether a result is significant, remember that we need to calculate a test statistic, and see where that fits on its underlying distribution. Here, our test statistic is handily named the #strong[chi-square statistic]. To calculate the chi-squared test statistic we use the following formula:

$ chi^2 = Sigma frac(\( O - E \)^2, E) $

Where:

- O = #strong[observed value]

- E = #strong[expected] #strong[value]

The English translation of that above formula can be described in four steps:

+ Calculate observed count - expected count

+ Square that difference

+ Divide it by the expected count

+ Do this for each cell, and add them all up

We'll look at this in more detail when we look at the actual tests. For the time being, here's the key takeaway: have a look at the two graphs below, representing the observed and expected values of two different datasets.

#box(image("04-chisquares_files/figure-typst/unnamed-chunk-4-1.svg"))

Have a think about the following:

+ What is each graph telling you?

+ The left graph appears to show noticeable differences between the observed and expected values. Based on the mathematical formula above, what will happen to the chi-square value?

+ Each graph represents one set of data. Based on your answers to a) and b) above, which one of the two would you expect to demonstrate a significant effect?

== The chi-square distribution
<the-chi-square-distribution>
#block(fill: rgb("#f5f5f5"))[
On the previous page we introduced the formula for a chi-square test statistic. But what do we do with it? We'll go through this below in detail, given that this is the first time we're coming across an actual test. While a computer will do all of this stuff automatically, it's useful to know the actual mechanisms underlying the test.

]
=== The chi-square distribution
<the-chi-square-distribution-1>
Recall from Week 6 about how hypothesis tests work - we calculate a test statistic that conforms to a particular distribution, and we assess how likely our observed test statistic is (or greater) on this distribution, assuming the null hypothesis is true. This gives us the p-value for that test. With that in mind, the chi-square distribution that underlies the chi-square test looks something like this:

#box(image("04-chisquares_files/figure-typst/unnamed-chunk-5-1.svg"))

The shape of the chi-square distribution is only dependent on the degrees of freedom (#emph[df]). We'll look at how to calculate degrees of freedom for various tests, including the family of chi-square tests, as we move along the subject.

Here is the same set of lines above, but shown in their own plot this time:

#box(image("04-chisquares_files/figure-typst/unnamed-chunk-6-1.svg"))

As you can hopefully see, the chi-square distribution is very heavily skewed at lower degrees of freedom (and therefore in smaller sample sizes). As degrees of freedom increase though, it approximates a normal distribution. For instance, here's what the chi-square distribution looks like when #emph[df] = 100:

#box(image("04-chisquares_files/figure-typst/unnamed-chunk-7-1.svg"))

=== Hypothesis testing in chi-squares
<hypothesis-testing-in-chi-squares>
At this point, also recall that #emph[p]-values are the probability that we would get our observed result (or greater), assuming the null hypothesis is true.

Here is our first application of this concept. When we use a chi-square test, we are performing the following basic steps:

+ Establish null and alternative hypotheses
+ Determine alpha level (in this case, $alpha$ = .05 as always)
+ Calculate our test statistic - here, this is the chi-square statistic
+ Compare our chi-square test statistic against the chi-square distribution
+ Calculate how likely we would have seen our chi-square value or greater on this distribution a. Or, alternatively, establish a critical chi-square value - the value that must be crossed for a result to be significant

We'll expand on this more in the next couple of pages.

=== Calculating significance
<calculating-significance>
Let's say that we have a #emph[df] of 5. How do we know where the critical chi-square value is?

For that, we consult a chi-square table. This table gives the critical chi-square value at a set degrees of freedom and alpha level. These are freely available online, but here's a short excerpt. To read this table:

- The far-left column lists different degrees of freedom. We need to find the row that corresponds to #emph[df] = 5.
- Each column provides critical chi-squares at different alpha levels. We want to find the column that says .05.
- The number at both of these points tells us the critical chi-square value.

#box(image("img/w7_chisq_table.png"))

So, for a #emph[df] = 5 and an $alpha$ = .05, the critical chi-square value is 11.07. If our own chi-square value is greater than this, the probability of that value or greater occurring (assuming the null) will be less than 5%; i.e.~the boundary for statistical significance.

In picture form:

#box(image("img/w7_chisq_df_5.png"))

Hopefully that makes sense - this kind of logic is pretty much identical to the other tests that we will cover in the coming weeks!

== Goodness of fit
<goodness-of-fit>
#block(fill: rgb("#f5f5f5"))[
Now that we've covered the conceptual groundwork for chi-square tests in general, we can now start looking at actual tests that can help us answer research questions. The most basic chi-square test is the goodness of fit test.

]
=== Goodness of fit tests
<goodness-of-fit-tests>
Goodness of fit tests are used when we want to compare a set of categorical data against a hypothetical distribution. Goodness of fit tests require one categorical variable - as the name implies, a goodness of fit test looks at whether the proportions of categories/levels in this variable fits an expected distribution. In other words, do our counts for each category match what we would expect under the null?

"Distribution" in this context means probability distributions, and can apply to a wide range of scenarios. For the purposes of what we're learning here, we'll stick to a question along the lines of: "do the categories of variable X align with their expected probabilities"?

=== Example
<example>
An example question that we look at in the seminar is Do Skittle bags have an even number of each colour? In the seminar, we go through whether or not a random bag has an even split of colours.

Here on Canvas, we'll now tackle their equally delicious rivals, M&Ms.~The data and analysis come courtesy of Rick Wicklin, a data analyst at SAS (who also make statistics software). You can read his full blog here: #link("https://blogs.sas.com/content/iml/2017/02/20/proportion-of-colors-mandms.html")[The distribution of colors for plain M&M candies]. We'll be recreating Rick's first analysis here. We're sticking with the candy theme because a) they're delicious and b) the M&Ms are a great way to introduce what to do when expected proportions are not equal.

M&Ms come in six colours: red, blue, green, brown, orange and yellow. Unlike Skittles, these colours are not distributed equally within each bag of M&Ms.~In 2008, Mars (the parent company) published the following percentage breakdown of colours:

- 13% red
- 20% orange
- 14% yellow
- 16% green
- 24% blue
- 13% brown

Rick collected his data in 2017, and so was interested in seeing if the proportions observed in his 2017 sample of M&Ms aligned with the distribution of colours listed in 2008.

A goodness of fit is the perfect test for this scenario because:

- We are making a claim about a distribution
- Our variable (colour) is categorical
- A chi-square goodness of fit will allow us to test whether the distribution of colours in a sample of M&Ms aligns with the published proportions.

Here's our dataset:

#block[
#Skylighting(([#NormalTok("mnm_data ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_7\"");#NormalTok(", ");#StringTok("\"W7_M&M.csv\"");#NormalTok("))");],
[#FunctionTok("head");#NormalTok("(mnm_data)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 2");],
[#NormalTok("     id colour");],
[#NormalTok("  <dbl> <chr> ");],
[#NormalTok("1     1 Red   ");],
[#NormalTok("2     2 Red   ");],
[#NormalTok("3     3 Red   ");],
[#NormalTok("4     4 Red   ");],
[#NormalTok("5     5 Red   ");],
[#NormalTok("6     6 Red   ");],));
]
]
=== Calculating (\\^2)
<calculating-2>
In goodness of fit tests, we first calculated the expected frequencies. In this example though, the expected proportions aren't equal - and so we have to be mindful of this when calculating expected values. See the expected count cell for Red M&Ms for how expected value is worked out in this instance.

We can draw this up in table form alongside our own data:

#table(
  columns: 4,
  align: (left,right,right,left,),
  table.header([Colour], [Observed], [Expected proportion], [Expected count],),
  table.hline(),
  [Blue], [133], [0.24], [170.88],
  [Brown], [96], [0.13], [92.56],
  [Green], [139], [0.16], [113.92],
  [Orange], [133], [0.20], [142.4],
  [Red], [108], [0.13], [$712 times 0.13 = 92.56$],
  [Yellow], [103], [0.14], [99.68],
)
Then we would use the formula we saw on the previous page to calculate a chi-square statistic. However, since we're doing this in R we'll skip the manual maths.

$ chi^2 = Sigma frac(\( O - E \)^2, E) $

If we have a look at the observed vs expected values, we might have a good idea of what's going on already:

#box(image("04-chisquares_files/figure-typst/unnamed-chunk-12-1.svg"))

=== Using R
<using-r>
The relevant function for doing a chi-square test in R is the #NormalTok("chisq.test()"); function.#footnote[There is an analogous function called #NormalTok("chisq_test()"); in the #NormalTok("rstatix"); package, but the base R #NormalTok("chisq.test()"); is easy enough to learn.]

By default, the #NormalTok("chisq.test()"); function in R will assume that your categories have an equal chance of happening. However, in this instance we know that the colours are not evenly distributed. To ensure the proper probabilities are set beforehand, this needs to be specified by giving the #NormalTok("p"); argument within #NormalTok("chisq.test()");. Note that the order of the expected probabilities needs to match the order they appear in the dataset (R will generally order these alphabetically unless told otherwise):

#block[
#Skylighting(([#CommentTok("# This pulls the relevant variable directly");],
[#NormalTok("w7_mnm_table ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("table");#NormalTok("(mnm_data");#SpecialCharTok("$");#NormalTok("colour)");],
[],
[#NormalTok("w7_mnm_chisq ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("chisq.test");#NormalTok("(w7_mnm_table, ");],
[#NormalTok("                            ");#AttributeTok("p =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#FloatTok("0.24");#NormalTok(", ");#FloatTok("0.13");#NormalTok(", ");#FloatTok("0.16");#NormalTok(", ");#FloatTok("0.20");#NormalTok(", ");#FloatTok("0.13");#NormalTok(", ");#FloatTok("0.14");#NormalTok("))");],));
]
#block[
#callout(
body: 
[
If you need to order your variable a certain way, you should use the #NormalTok("factor()"); function. You will need to specify a #NormalTok("levels"); argument, which describes the ordering of the categories/groups, and optionally a #NormalTok("labels"); argument which gives each one a label. Both arguments take vectors, i.e.~#NormalTok("labels = c(\"1\", \"2\", \"3\")");.

]
, 
title: 
[
R Note: Manually ordering variables
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
=== Output
<output>
Here's what our output looks like. First is our table of proportions. This can be really useful in laying out the data and seeing where the differences between observed and expected proportions might lie.

#block[
#Skylighting(([#NormalTok("w7_mnm_chisq");#SpecialCharTok("$");#NormalTok("observed");],));
#block[
#Skylighting(([],
[#NormalTok("  Blue  Brown  Green Orange    Red Yellow ");],
[#NormalTok("   133     96    139    133    108    103 ");],));
]
#Skylighting(([#NormalTok("w7_mnm_chisq");#SpecialCharTok("$");#NormalTok("expected");],));
#block[
#Skylighting(([#NormalTok("  Blue  Brown  Green Orange    Red Yellow ");],
[#NormalTok("170.88  92.56 113.92 142.40  92.56  99.68 ");],));
]
]
Next, here is our test output. The result is significant (#emph[p] = .004), suggesting that the 2017 bag of M&Ms does not follow the same distribution of colours as the 2008 values. (If you read the rest of Rick's blog post, it turns out that somewhere between 2008 and 2017 they changed where M&Ms are made, and actually split production across two factories that produce different distributions of colours. Rick eventually found out that his bag most likely came from one of the plants, although Mars has not made these proportions public like they used to.)

#block[
#Skylighting(([#NormalTok("w7_mnm_chisq");],));
#block[
#Skylighting(([],
[#NormalTok("    Chi-squared test for given probabilities");],
[],
[#NormalTok("data:  w7_mnm_table");],
[#NormalTok("X-squared = 17.353, df = 5, p-value = 0.003877");],));
]
]
Here is an example write-up of these results:

#block(fill: rgb("#cce3c8"))[
A chi-square test of goodness of fit was conducted to see whether the number of M&Ms aligned with the expected proportions published in 2008. There was a significant difference between the observed and expected proportions ($chi^2$\(5, #emph[N] = 712) = 17.35, #emph[p] = .004). There were more green M&Ms and less blue M&Ms than expected.

]
== Tests of independence
<tests-of-independence>
#block(fill: rgb("#f5f5f5"))[
The next chi-square test we will cover is probably the most common - the chi-square test of independence. Here, we move from one categorical variable to two.

]
Chi square tests of independence are used when we want to test whether two categorical variables are associated with each other (i.e.~show a relationship). Some examples of this question might take on the following:

- Is smoking history (yes/no) associated with lung cancer diagnosis? (yes/no)
- Is there an association between gender and employment status?

=== Example scenario
<example-scenario>
We'll start off with a very basic example. In the below dataset, children from several schools were surveyed regarding what instrument they played. This dataset focuses on two instruments that have historically been seen as gendered (e.g.~see Abeles 2009) - clarinet and drums. The sex of the child playing the instrument was also recorded.

Our research question is: is there an association between sex and instrument choice?

Dataset:

#block[
#Skylighting(([#NormalTok("instrument_data ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_7\"");#NormalTok(", ");#StringTok("\"W7_instruments.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 122 Columns: 3");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (2): instrument, sex");],
[#NormalTok("dbl (1): id");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
#Skylighting(([#FunctionTok("head");#NormalTok("(instrument_data)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 3");],
[#NormalTok("     id instrument sex  ");],
[#NormalTok("  <dbl> <chr>      <chr>");],
[#NormalTok("1     1 clarinet   M    ");],
[#NormalTok("2     2 clarinet   M    ");],
[#NormalTok("3     3 clarinet   M    ");],
[#NormalTok("4     4 clarinet   F    ");],
[#NormalTok("5     5 clarinet   F    ");],
[#NormalTok("6     6 clarinet   M    ");],));
]
]
=== Contingency tables
<contingency-tables>
The primary way of 'drawing up' categorical data, particularly when two variables are involved, is to draw a contingency table. A contingency table is a two-way table that shows how many participants/items/objects fall under each combination of our two variables. Here is a contingency table of our data below:

#block[
#Skylighting(([#NormalTok("w7_instrument_table ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("table");#NormalTok("(instrument_data");#SpecialCharTok("$");#NormalTok("instrument,");],
[#NormalTok("                             instrument_data");#SpecialCharTok("$");#NormalTok("sex)");],
[],
[#NormalTok("w7_instrument_table  ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("addmargins");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("          ");],
[#NormalTok("             F   M Sum");],
[#NormalTok("  clarinet  51  48  99");],
[#NormalTok("  drums      6  17  23");],
[#NormalTok("  Sum       57  65 122");],));
]
]
=== Expected frequencies
<expected-frequencies>
To calculate expected frequencies in a two-way contingency table (i.e.~a test of independence), we use the following formula:

$ E = frac(R times C, N) $

Where R = row total and column = column total.

Let's put this into practice with girls who play the clarinet (highlighted above). The row total for this cell is 99 (i.e.~total number of clarinet players). The column total is 57 (total number of girls). To calculate an expected value for this cell, we would therefore calculate the following:

$E = frac(99 times 57, 122)$

This works out to be roughly 46.25 - which means that we would expect roughly 46 female clarinet players. We then go through and calculate this for each cell, so that we have all of our expected values.

Once we've done that, we can then calculate our chi-square test statistic using the same formula as always:

$ chi^2 = Sigma frac(\( O - E \)^2, E) $

=== Output
<output-1>
Here's our output! Firstly, our contingency table:

#block[
#Skylighting(([#NormalTok("w7_inst_chisq ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("chisq.test");#NormalTok("(w7_instrument_table, ");#AttributeTok("correct =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],
[],
[#NormalTok("w7_inst_chisq");#SpecialCharTok("$");#NormalTok("observed");],));
#block[
#Skylighting(([#NormalTok("          ");],
[#NormalTok("            F  M");],
[#NormalTok("  clarinet 51 48");],
[#NormalTok("  drums     6 17");],));
]
#Skylighting(([#NormalTok("w7_inst_chisq");#SpecialCharTok("$");#NormalTok("expected");],));
#block[
#Skylighting(([#NormalTok("          ");],
[#NormalTok("                 F       M");],
[#NormalTok("  clarinet 46.2541 52.7459");],
[#NormalTok("  drums    10.7459 12.2541");],));
]
]
Next is our chi-square test output. As you can see, our test of independence suggests a significant result (#emph[p] = .03). In other words, we reject the null hypothesis that there is no association between instrument and sex.

#block[
#Skylighting(([#NormalTok("w7_inst_chisq");],));
#block[
#Skylighting(([],
[#NormalTok("    Pearson's Chi-squared test");],
[],
[#NormalTok("data:  w7_instrument_table");],
[#NormalTok("X-squared = 4.848, df = 1, p-value = 0.02768");],));
]
]
Like the previous page, here's an example write-up of our results:

#block(fill: rgb("#cce3c8"))[
A chi-square test of association was conducted to examine whether there was an association between sex and instrument choice. A significant association was observed ($chi^2$\(1, #emph[N] = 122) = 4.85, #emph[p] = .028; Cramer's #emph[V] = .199). There were more male drummers and less female drummers than expected.

]
Note that as part of the write-up above, you would also include a brief interpretation of the effect size - but we will discuss this on the next page.

== Effect sizes for chi-squares
<effect-sizes-for-chi-squares>
#block(fill: rgb("#f5f5f5"))[
This is the first time we're coming across effect sizes for any test - thankfully, we start with relatively easy ones to wrap your head around. We will cover two effect sizes: phi ($phi.alt$) and Cramer's #emph[V], both of which apply when conducting a test of independence.

]
=== Phi
<phi>
Phi ($phi.alt$) is an effect size for chi-squares that applies only to 2x2 designs. The formula for phi is:

$ phi.alt = sqrt(chi^2 / n) $

Essentially, it is the chi-square test statistic divided by the sample size, which is then square rooted. Again, it only works for 2x2 designs - i.e.~each categorical variable can only have two categories within it.

=== Cramer's V
<cramers-v>
Cramer's #emph[V] is another effect size for chi-squares, but one that can be used for anything beyond a 2x2 design as well. The formula for Cramer's #emph[V] is similar:

$ V = sqrt(frac(chi^2, n \( k - 1 \))) $ Here, #emph[k] refers to the number of groups in the variable with the lowest number of groups. So for example, in a 2x3 design, one variable has 2 levels and the other has 3; #emph[k] = 2 in this instance.

Phi and Cramer's #emph[V] can both be calculated in R with the following functions from the #NormalTok("effectsize"); package, a handy package that will calculate many common effect size measures. Like #NormalTok("chisq.test()");, both functions will work if you give them a contingency table. Helpfully, both functions calculate 95% CIs.

#block[
#Skylighting(([#NormalTok("effectsize");#SpecialCharTok("::");#FunctionTok("phi");#NormalTok("(w7_instrument_table, ");#AttributeTok("adjust =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(", ");#AttributeTok("alternative =");#NormalTok(" ");#StringTok("\"two.sided\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Phi  |       95% CI");],
[#NormalTok("-------------------");],
[#NormalTok("0.20 | [0.00, 0.38]");],));
]
#Skylighting(([#NormalTok("effectsize");#SpecialCharTok("::");#FunctionTok("cramers_v");#NormalTok("(w7_instrument_table, ");#AttributeTok("adjust =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(", ");#AttributeTok("alternative =");#NormalTok(" ");#StringTok("\"two.sided\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Cramer's V |       95% CI");],
[#NormalTok("-------------------------");],
[#NormalTok("0.20       | [0.00, 0.38]");],));
]
]
=== Interpretation
<interpretation>
Phi and Cramer's #emph[V] are essentially both correlation coefficients (more on this in Week 10). Both phi and Cramer's #emph[V] can only be between 0 and 1. For this subject, the size of Cramer's #emph[V] and phi can be interpreted as follows:

- If the effect size = .10, the effect is small
- If effect size = .30, the effect is medium
- If effect size = .50 or above, the effect is large

=== Practice
<practice>
Given the following results from a 2x2 chi-square test of independence:

- $chi^2$ = 5.45
- #emph[N] = 46

Calculate both phi and Cramer's #emph[V]. (You should get the same answer, but have a go at trying it both ways!)

== Bonus: McNemar's Test
<bonus-mcnemars-test>
#block(fill: rgb("#f5f5f5"))[
The chi-square test of independence, as the name implies, relies on the assumption of independence - that variable A is statistically independent of B. But what happens if we have a relationship that doesn't meet this assumption? The most common kind is when data is #emph[paired] or #emph[repeated], i.e.~participants are measured on the same variable twice. McNemar's test allows us to apply chi-square techniques to this kind of data.

]
=== McNemar's test
<mcnemars-test>
#strong[McNemar's test] is used for when you have repeated-measures categorical data. Specifically, it applies to a 2x2 repeated measures contingency table. This will apply when you have one sample tested #strong[twice] on a #strong[binary outcome]. The most common example of this is a yes/no outcome, before and after something (e.g.~an intervention.

McNemar's test will apply to situations where you have one sample tested twice like this:

#table(
  columns: 4,
  align: (left,left,left,left,),
  table.header([], [Timepoint 2 - A], [Timepoint 2 - B], [Total],),
  table.hline(),
  [], [], [], [],
  [Timepoint 1 - A], [], [], [],
  [Timepoint 1 - B], [], [], [],
  [Total], [], [], [],
)
=== Mathematical basis
<mathematical-basis>
Consider the table above. We can formulate the cells between each combination of predictors, and their totals, as follows:

#table(
  columns: 4,
  align: (left,left,left,left,),
  table.header([], [Timepoint 2 - A], [Timepoint 2 - B], [Total],),
  table.hline(),
  [], [], [], [],
  [Timepoint 1 - A], [a], [b], [a + b],
  [Timepoint 1 - B], [c], [d], [c + d],
  [Total], [a + c], [b + d], [N],
)
Essentially, in this instance cell #emph[a] represents the number of cases/participants in T1-A and T2-A, #emph[b] is T1-A and T2-B etc etc. Each cell has two #strong[marginal probabilities], which are the row and column totals corresponding to that cell. Cell #emph[a], for example, has marginal probabilities of #emph[a + b] (the row total) and #emph[a + c] (the column total). Cell d has marginal probabilities of #emph[c + d] and #emph[b + d].

The null hypothesis in this scenario is that the #strong[two marginal properties for each outcome are the same]. This is a principle known as marginal homogeneity. In essence, the McNemar test tests the hypothesis that the proportion of participants responding A beforehand is the same at that responding A afterwards. The marginal probability in this instance is a + b (proportion of response A at timepoint 1) and a + c (proportion of response A at timepoint 2).

The same hypothesis applies to the proportion of participant saying B before and after, corresponding to cell d.~In this case, the marginal probabilities are c + d (time 1) and b + d (time 2).

We can express this null hypothesis like this:

$ p_a + p_b = p_a + p_c $

$ p_b + p_d = p_c + p_d $

We can simplify both equations by removing identical terms from both sides of the equation. You might see then that both equations cancel out to simply be:

$ p_b = p_c $

That, in effect, is our null hypothesis - that the probability of cell b is identical to cell c! So now we can express our null and alternative hypotheses:

- $H_0 : p_b = p_c$
- $H_1 : p_b eq.not p_c$

Our chi-square test statistic is calculated as follows:

$ chi^2 = frac(\( b - c \)^2, b + c) $

And then from here on, the process of deriving a #emph[p]-value is identical to a regular chi-square test, with the exception that the df is always df = 1 (remember we have a 2 x 2 table, and the formula for a df in a two-way chi-square test is to subtract 1 from each and multiply them together).

=== Example
<example-1>
Below is a fictional dataset from 70 registered voters in a fictional country. The 70 voters were asked whether they intended to vote for the current government twice: before event X happened in the government and after event X. Their responses were recorded as simple Yes-No answers.

#block[
#Skylighting(([#NormalTok("w7_voting ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_7\"");#NormalTok(", ");#StringTok("\"W7_voting.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 71 Columns: 3");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (2): before, after");],
[#NormalTok("dbl (1): id");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
Here is a contingency table of our data:

#block[
#Skylighting(([#NormalTok("w7_voting_table ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("table");#NormalTok("(w7_voting");#SpecialCharTok("$");#NormalTok("before, w7_voting");#SpecialCharTok("$");#NormalTok("after) ");],
[],
[#NormalTok("w7_voting_table ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("addmargins");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("     ");],
[#NormalTok("      No Yes Sum");],
[#NormalTok("  No  18  28  46");],
[#NormalTok("  Yes 11  13  24");],
[#NormalTok("  Sum 29  41  70");],));
]
]
We can identify our b = 28 and our c = 11. We can calculate a relevant chi-squared test statistic using the formula above:

$ chi^2 = frac(\( b - c \)^2, b + c) $

$ chi^2 = frac(\( 28 - 11 \)^2, 28 + 11) $ $ chi^2 = frac(\( 17 \)^2, 39) $

$ chi^2 = 7.41 $

If we were doing this fully by hand, we could consult a chi-squared table and see what the relevant #emph[p]-value would be with this chi-squared value and a df = 1. However, we'll skip straight to Jamovi. A McNemar test can be run in R using the #NormalTok("mcnemar.test()"); function in base R:

#block[
#Skylighting(([#NormalTok("w7_voting_mcn ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("mcnemar.test");#NormalTok("(w7_voting_table, ");#AttributeTok("correct =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],
[],
[#NormalTok("w7_voting_mcn");],));
#block[
#Skylighting(([],
[#NormalTok("    McNemar's Chi-squared test");],
[],
[#NormalTok("data:  w7_voting_table");],
[#NormalTok("McNemar's chi-squared = 7.4103, df = 1, p-value = 0.006485");],));
]
]
The output looks like this, and confirms that there is a significant change in proportions before and after event ($chi^2$\(1, #emph[N] = 70) = 7.41, #emph[p] = .006). Based on the original values of #emph[b] and #emph[c], we can infer that this might be because more people changed their vote from No -\> Yes than the other way round.

= t-tests
<t-tests>
#emph[t]-tests are usually one of the first families of statistical tests that students learn when they take a research methods subject. I (Dan) pretty much learnt only #emph[t]-tests until my third year of my psychology major (I learnt chi-squares and other tests through taking separate statistics subjects through my uni's Department of Statistics before I learnt them in psychology). It's not hard to see why this is the case - #emph[t]-tests are really intuitive and simple to conduct, and so are an accessible way into learning statistical tests (even though chi-squares are even easier).

The family of #emph[t]-tests come into play when we have one categorical IV with two levels, and one continuous DV. As you can imagine, there are many instances where this kind of design comes into play, and you will see as much in the datasets and examples this week. There are nine datasets for you to play around this week (3 for each kind of test) - so hopefully that will give you plenty of practice!

By the end of this module you should be able to:

- Describe how a t-test works in principle
- Conduct three forms of chi-square tests: one-sample, independent-samples and paired-samples
- Calculate and interpret an appropriate effect size for the above tests

#figure([
#box(image("index_files\\mediabag\\control_group.png"))
], caption: figure.caption(
position: bottom, 
[
#link("https://xkcd.com/2576/")[xkcd: Control Group]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


== #emph[t]-tests and the #emph[t]-distribution
<t-tests-and-the-t-distribution>
We begin this week's module in much the same way we went through last week's. We'll look at the shape of the underlying distribution, and what determines the shape of that distribution. On this page we'll also go through what the basic premise of the #emph[t]-test is.

=== What is a #emph[t]-test?
<what-is-a-t-test>
The family of #emph[t]-tests, broadly speaking, are used when we want to compare one mean against another. This can take on three major forms, which we will go into later in the module:

+ Is this sample mean different from the population mean?
+ Are these two group means different?
+ Is the mean at point 1 different to the mean at point 2?

All of these instances require a comparison between two means, which the #emph[t]-tests will allow you to test for. So, in a general sense our hypotheses would be something like:

- $H_0$: The means between the two groups are not significantly different. (i.e.~$mu_1 = mu_2$)
- $H_1$: The means between the two groups are significantly different. (i.e.~$mu_1 eq.not mu_2$)

The question of when #emph[t]-tests should be used is hopefully somewhat obvious - in general, we use them we want to compare two means with each other. The important part is what kind of means they are:

- If we compare one sample mean to a hypothesised population mean, this is a one-sample #emph[t]-test
- If we compare two group means, this is an independent samples #emph[t]-test
- If we measure one group twice and compare the two means, this is a paired-samples #emph[t]-test.

In this module, we'll go through all three (but will emphasise the latter two especially as they see the most use).

=== The #emph[t]-statistic
<the-t-statistic>
Last week we introduced the chi-square statistic, which is the value that we use when we want to assess whether a result is significant. When we want to assess whether a difference between two means is significant we calculate a different test statistic, which (as the name implies) is the #emph[t]-statistic. While you won't be required to calculate this by hand this week, it would be good to wrap your head around the below formula so you understand how it works in principle:

$ t = frac(M_1 - M_2, S E) $

This is how #emph[t] is calculated conceptually - it is the difference in the two means over the standard error of the mean. Note that the world conceptually is stressed here because the actual formula is slightly different for each #emph[t]-test, but all work on this above principle. Again, we won't go through the maths of this in detail - this is beyond the scope of the subject!

=== The #emph[t]-distribution
<the-t-distribution>
By now, hopefully you're comfortable with the idea that we use our test statistic and find its position on its underlying probability distribution in order to calculate the #emph[p]-value. The underlying distribution of this test is the #emph[t]-distribution, which is depicted below. Note that like the chi-square distribution, degrees of freedom is the only parameter that determines its shape:

#block[
#Skylighting(([#NormalTok("Warning: Using `size` aesthetic for lines was deprecated in ggplot2 3.4.0.");],
[#NormalTok("ℹ Please use `linewidth` instead.");],));
]
#box(image("05-ttests_files/figure-typst/unnamed-chunk-3-1.svg"))

The one key difference between the #emph[t]-distribution and the chi-square distribution from a mathematical point of view is that the #emph[t]-distribution is symmetrical, much like the normal distribution (although they are not the same). Therefore, it is possible to get a negative #emph[t]-test statistic; however, this simply reflects the order in which the groups are being compared. E.g.

- Say that Group 1 - Group 2 gives a test statistic of #emph[t] = 1.5.
- If you were to enter the groups as Group 2 - Group 1 instead, the #emph[t] would be -1.5. This simply reflects the ordering of the groups.

=== The #emph[t]-table
<the-t-table>
Once again, like the chi-square we have a beautiful little table for calculating a critical #emph[t]-value. We won't go into too much depth over how this works because it works exactly like how it does for chi-squares - find the row corresponding to your degrees of freedom, then find the column corresponding to your alpha level.

Yes, there are a lot of cross-references to what we covered last week with chi-squares - and that's a good thing! The point here is that conceptually, the process of testing hypotheses using #emph[t]-tests is exactly the same as what we did with chi-squares, but the specific design and maths are different.

== Cohen's #emph[d]
<cohens-d>
This might be starting to sound a little familiar by now, but here are some effect sizes for #emph[t]-tests. Note that they're different to the Cramer's #emph[V] we saw in the chi-square test of independence last week - this is because it is a) conceptually different and b) interpreted differently too.

=== What is Cohen's #emph[d]?
<what-is-cohens-d>
Cohen's d is a measure of effect size that is used when comparing between two means (i.e.~in a #emph[t]-test). It essentially is a measure of the distance between the two means. See below for three pairs of means:

#box(image("05-ttests_files/figure-typst/unnamed-chunk-4-1.svg"))

If two groups aren't all that different (e.g.~panel A), then any effect of group will be small or negligible. If the two groups are further apart, however (like panel C), there is a more obvious effect of group - and so the size of the effect itself will be larger. Cohen's #emph[d] essentially is a measure of this 'distance'.

The basic formula for calculating Cohen's #emph[d] is: $ d = frac(M_1 - M_2, sigma_(p o o l e d)) $

In other words, Cohen's #emph[d] is calculated by taking the difference between the two group means and dividing that by the pooled standard deviation across both groups. Pooled SD is essentially an aggregate SD across both groups in the sample, and not something we'll concern ourselves with this week (because like the maths for the #emph[t]-statistic, the calculation of the pooled SD depends on the test and is hard).

=== Interpreting Cohen's #emph[d]
<interpreting-cohens-d>
Cohen provided some now-famous guidelines for interpreting the size of Cohen's #emph[d] values:

#table(
  columns: 2,
  align: (left,left,),
  table.header([Effect size], [Interpretation],),
  table.hline(),
  [d = .20], [Small],
  [d = .50], [Medium],
  [d = .80], [Large],
)
== One-sample #emph[t]-test
<one-sample-t-test>
The first test that we'll look at is the one-sample #emph[t]-test, which is the most simple of the three that we will look at this week.

=== One-sample #emph[t]-test
<one-sample-t-test-1>
A one-sample #emph[t]-test is used when we want to compare a sample against a hypothesised population value. It is useful when we already know the expected value of the parameter we're interested in, such as a population mean or a target value.

The basic hypotheses for a three-way interaction are:

- $H_0$: The sample mean is not significantly different from the hypothesised mean. (i.e.~$M = mu$)
- $H_1$: The sample mean is significantly different from the hypothesised mean. (i.e.~$M eq.not mu$)

It's worth noting that one-sample #emph[t]-tests aren't that commonly used because they require you to know the population value (or, if you hypothesise a value, you need to justify why). However, they're included here because they're still a part of the #emph[t]-test family, and they serve as a nice introduction to how #emph[t]-tests work.

=== Example data
<example-data>
Historically, scores in a fictional research methods class average at 72. This year, you are the subject coordinator for the first time, and you notice that last year's cohort appear to have really struggled. You want to see if there is a meaningful difference between the cohort's average grade and what the target grade should be.

Here's the dataset below:

#block[
#Skylighting(([#NormalTok("w8_grades ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_8\"");#NormalTok(", ");#StringTok("\"W8_grades.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 128 Columns: 2");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("dbl (2): id, grade");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
#Skylighting(([#FunctionTok("head");#NormalTok("(w8_grades)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 2");],
[#NormalTok("     id grade");],
[#NormalTok("  <dbl> <dbl>");],
[#NormalTok("1     1    60");],
[#NormalTok("2     2    66");],
[#NormalTok("3     3    70");],
[#NormalTok("4     4    72");],
[#NormalTok("5     5    63");],
[#NormalTok("6     6    71");],));
]
]
=== Assumption checks
<assumption-checks>
There is only one relevant assumption that we need to check for the one-sample #emph[t]-test: whether our data is distributed normally or not. We can do this in two ways. The first and quickest is through a test called the Shapiro-Wilks test (often abbreviated as the SW test). The SW test is a significant test of departures from normality. The statistic in question, W, is an index of normality. If W is close to 1, then data is normally distributed; the smaller W becomes, the more non-normal the data is.

A significant #emph[p]-value on the SW test suggests that the data is non-normal. Thankfully, that isn't an issue here.

#block[
#Skylighting(([#FunctionTok("shapiro.test");#NormalTok("(w8_grades");#SpecialCharTok("$");#NormalTok("grade)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  w8_grades$grade");],
[#NormalTok("W = 0.98652, p-value = 0.2395");],));
]
]
The second way is through a Q-Q plot (Quantile-Quantile) plot. Essentially, these plot where data should be (if the data are normally distributed) against where the data actually is. If the normality assumption is intact, most of the data should lie on or close to the straight line, like the left plot. Data that looks like the right, where the data curves away from the central line, is more likely to be non-normally distributed.

#box(image("img/w8_qqplots.svg"))

To draw a Q-Q plot in R, the base functions #NormalTok("qqnorm()"); and #NormalTok("qqline()"); can be used. #NormalTok("qqnorm()"); will draw the basic Q-Q plot, while #NormalTok("qqline()"); will draw a straight line through the graph. Note that #NormalTok("qqnorm()"); must be run first before #NormalTok("qqline()"); can be used.

In this case, since we want to draw a Q-Q plot of a single variable, we just need to give the name of the column/variable we are interested in using #NormalTok("data$variable"); format.

#Skylighting(([#FunctionTok("qqnorm");#NormalTok("(w8_grades");#SpecialCharTok("$");#NormalTok("grade)");],
[#FunctionTok("qqline");#NormalTok("(w8_grades");#SpecialCharTok("$");#NormalTok("grade)");],));
#box(image("05-ttests_files/figure-typst/unnamed-chunk-9-1.svg"))

In our case, most of the points fall quite close to the main line, so we seem to be ok here - in line with our Shapiro-Wilks test (though this won't always be the case).

=== Output
<output-2>
Here are our descriptive statistics. They alone might already tell us something is going on:

#Skylighting(([#NormalTok("w8_grades ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("mean =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(grade, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("sd =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(grade, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("median =");#NormalTok(" ");#FunctionTok("median");#NormalTok("(grade, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#NormalTok("  ) ");#SpecialCharTok("%>%");],
[#NormalTok("  knitr");#SpecialCharTok("::");#FunctionTok("kable");#NormalTok("(");#AttributeTok("digits =");#NormalTok(" ");#DecValTok("2");#NormalTok(")");],));
#table(
  columns: 3,
  align: (right,right,right,),
  table.header([mean], [sd], [median],),
  table.hline(),
  [67.09], [5.38], [67.5],
)
To run a one-sample #emph[t]-test, the basic function is the #NormalTok("t.test()"); function. For a one-sample #emph[t]-test, you must provide the argument #NormalTok("x"); (the data) and #NormalTok("mu");, which is the hypothesised population mean.

Below is our output from the one-sample #emph[t]-test. Our result tells us that there is a significant difference between the mean of the sample (#emph[M] = 67.09) and the hypothesised mean of 72 (#emph[p] \< .001). The mean difference here is calculated as Sample - Hypothesis; therefore, a difference of -4.91 means that the sample mean is 4.91 units #emph[lower] than the population mean (which hopefully would have been evident from the descriptives anyway). This means that for some reason, last year's cohort are performing worse than the expected average.

#block[
#callout(
body: 
[
For a one-sample #emph[t]-test, Jamovi will give you a 95% confidence interval around the mean difference - in this case, Jamovi will report the 95% CI as = \[-5.85, -3.97\]. R however will give you a CI around the actual #emph[sample mean]. In this case, the 95% confidence interval for the group mean is \[66.15, 68.03\].

Really though, this is giving us the same information; 72 - 66.15 = 5.85, and 72 - 68.03 = 3.97. So the only difference between R and Jamovi here is what the 95% CI is placed around, but the actual inference itself doesn't change.

]
, 
title: 
[
R-Note: Confidence intervals for t-tests
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
#block[
#Skylighting(([#FunctionTok("t.test");#NormalTok("(w8_grades");#SpecialCharTok("$");#NormalTok("grade, ");#AttributeTok("mu =");#NormalTok(" ");#DecValTok("72");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    One Sample t-test");],
[],
[#NormalTok("data:  w8_grades$grade");],
[#NormalTok("t = -10.342, df = 127, p-value < 2.2e-16");],
[#NormalTok("alternative hypothesis: true mean is not equal to 72");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" 66.14570 68.02617");],
[#NormalTok("sample estimates:");],
[#NormalTok("mean of x ");],
[#NormalTok(" 67.08594 ");],));
]
]
Anoter way of writing a one-sample #emph[t]-test is to use #NormalTok("variable ~ 1"); formula notation. The #NormalTok("~ 1"); is used to indicate that we are running a one-sample #emph[t]-test. We still need to define #NormalTok("mu = 72"); to set our hypothesised population mean.

#block[
#Skylighting(([#FunctionTok("t.test");#NormalTok("(grade ");#SpecialCharTok("~");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("data =");#NormalTok(" w8_grades, ");#AttributeTok("mu =");#NormalTok(" ");#DecValTok("72");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    One Sample t-test");],
[],
[#NormalTok("data:  grade");],
[#NormalTok("t = -10.342, df = 127, p-value < 2.2e-16");],
[#NormalTok("alternative hypothesis: true mean is not equal to 72");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" 66.14570 68.02617");],
[#NormalTok("sample estimates:");],
[#NormalTok("mean of x ");],
[#NormalTok(" 67.08594 ");],));
]
]
Alternatively, you can use the #NormalTok("t_test()"); function in #NormalTok("rstatix");. This function also requires formula notation. #NormalTok("detailed = TRUE"); will print a detailed output that will give the 95% CI for the mean as well:

#block[
#Skylighting(([#NormalTok("w8_grades ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("t_test");#NormalTok("(grade ");#SpecialCharTok("~");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("mu =");#NormalTok(" ");#DecValTok("72");#NormalTok(", ");#AttributeTok("detailed =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 12");],
[#NormalTok("  estimate .y.   group1 group2     n statistic        p    df conf.low conf.high");],
[#NormalTok("*    <dbl> <chr> <chr>  <chr>  <int>     <dbl>    <dbl> <dbl>    <dbl>     <dbl>");],
[#NormalTok("1     67.1 grade 1      null …   128     -10.3 1.47e-18   127     66.1      68.0");],
[#NormalTok("# ℹ 2 more variables: method <chr>, alternative <chr>");],));
]
]
As we have previously done for chi-square tests, we will want to calculate an effect size for our #emph[t]-test. The #NormalTok("cohens_d()"); function from #NormalTok("effectsize"); can handle the calculation of effect sizes for all three variants of #emph[t]-tests. One thing that's quite nice about this function is that the required syntax for #NormalTok("cohens_d()"); is nearly identical to that for #NormalTok("t.test()"); - meaning that the correct type of Cohen's #emph[d] (one-sample, independent samples, paired) will be calculated based on what you put in.

For a one-sample t-test, for instance, you can write the syntax exactly as you would for #NormalTok("t.test()");:

#block[
#Skylighting(([#CommentTok("# One-sample");],
[#CommentTok("# t.test(w8_grades$grade, mu = 72)");],
[#NormalTok("effectsize");#SpecialCharTok("::");#FunctionTok("cohens_d");#NormalTok("(w8_grades");#SpecialCharTok("$");#NormalTok("grade, ");#AttributeTok("mu =");#NormalTok(" ");#DecValTok("72");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Cohen's d |         95% CI");],
[#NormalTok("--------------------------");],
[#NormalTok("-0.91     | [-1.12, -0.71]");],
[],
[#NormalTok("- Deviation from a difference of 72.");],));
]
]
The alternate way of specifying a one-sample #emph[t]-test, the #NormalTok("var ~ 1"); format, also works. #NormalTok("cohens_d()"); will recognise both.

#block[
#Skylighting(([#CommentTok("# One-sample - alternate");],
[#CommentTok("# t.test(grade ~ 1, data = w8_grades, mu = 72)");],
[#NormalTok("effectsize");#SpecialCharTok("::");#FunctionTok("cohens_d");#NormalTok("(grade ");#SpecialCharTok("~");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("data =");#NormalTok(" w8_grades, ");#AttributeTok("mu =");#NormalTok(" ");#DecValTok("72");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Cohen's d |         95% CI");],
[#NormalTok("--------------------------");],
[#NormalTok("-0.91     | [-1.12, -0.71]");],
[],
[#NormalTok("- Deviation from a difference of 72.");],));
]
]
Alternatively, you can use the #NormalTok("rstatix"); package. This will give the same values, but the confidence intervals generated by #NormalTok("effectsize"); are traditional confidence intervals, whereas #NormalTok("rstaix"); uses a different method (which we need not concern ourselves with). In any case, the actual width of the intervals should be similar. Just note that for paired samples Cohen's #emph[d], long data is required (as is the case with #emph[t]-tests in #NormalTok("rstatix");).

For a one-sample #emph[t]-test, the formula once again needs to be in #NormalTok("var ~ 1"); format and #NormalTok("mu"); must be specified:

#block[
#Skylighting(([#NormalTok("w8_grades ");#SpecialCharTok("%>%");#NormalTok(" ");],
[#NormalTok("  rstatix");#SpecialCharTok("::");#FunctionTok("cohens_d");#NormalTok("(grade ");#SpecialCharTok("~");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("mu =");#NormalTok(" ");#DecValTok("72");#NormalTok(", ");#AttributeTok("ci =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("ci.type =");#NormalTok(" ");#StringTok("\"norm\"");#NormalTok(") ");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 8");],
[#NormalTok("  .y.   group1 group2     effsize     n conf.low conf.high magnitude");],
[#NormalTok("* <chr> <chr>  <chr>        <dbl> <int>    <dbl>     <dbl> <ord>    ");],
[#NormalTok("1 grade 1      null model  -0.914   128     -1.1     -0.72 large    ");],));
]
]
Here is an example write-up of the above:

#block(fill: rgb("#cce3c8"))[
A one-sample #emph[t]-test was conducted to examine whether grades in the research methods class differed from the historical average of 72. The sample's grades (#emph[M] = 67.09, #emph[SD] = 5.38) were significantly lower than the historical average (#emph[t]\(127) = -10.3, #emph[p] \< .001), with a mean difference of 4.91 (95% CI = \[-5.85, -3.97\]). This effect was large in size (#emph[d] = -0.91).

]
== Independent samples t-test
<independent-samples-t-test>
The independent-samples #emph[t]-test is one of the most common tests that you will see in literature - it is one of the bread-and-butter tests of many music psychologists (for better or worse).

=== Independent samples
<independent-samples>
Independent samples #emph[t]-tests are used when we want to compare two separate groups on one continuous outcome. They're therefore well-suited for data with one categorical IV with two levels, against one continuous outcome.

=== Example data
<example-data-1>
For this example we'll use a contrived but really simple example. A group of self-reported professional and amateur musicians were asked how many years of training they had on their primary instrument.

#block[
#Skylighting(([#NormalTok("w8_training ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_8\"");#NormalTok(", ");#StringTok("\"W8_training.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 60 Columns: 3");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (1): Group");],
[#NormalTok("dbl (2): Participant, Years_training");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
#Skylighting(([#FunctionTok("head");#NormalTok("(w8_training)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 3");],
[#NormalTok("  Participant Years_training Group       ");],
[#NormalTok("        <dbl>          <dbl> <chr>       ");],
[#NormalTok("1           1              8 Professional");],
[#NormalTok("2           2              9 Professional");],
[#NormalTok("3           3              4 Professional");],
[#NormalTok("4           4              7 Professional");],
[#NormalTok("5           5              9 Professional");],
[#NormalTok("6           6              6 Professional");],));
]
]
Let us start with a nice plot. With some clever piping of functions, we can go straight from calculating summary descriptives to plotting using #NormalTok("ggplot"); in one smooth chain of events, using the code below:

#Skylighting(([#NormalTok("w8_training ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(Group) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("mean =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(Years_training, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("sd =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(Years_training, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("se =");#NormalTok(" sd");#SpecialCharTok("/");#FunctionTok("n");#NormalTok("()");],
[#NormalTok("  ) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" Group, ");#AttributeTok("y =");#NormalTok(" mean)");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("size =");#NormalTok(" ");#DecValTok("3");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_errorbar");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("ymin =");#NormalTok(" mean ");#SpecialCharTok("-");#NormalTok(" ");#FloatTok("1.96");#SpecialCharTok("*");#NormalTok("se,");],
[#NormalTok("    ");#AttributeTok("ymax =");#NormalTok(" mean ");#SpecialCharTok("+");#NormalTok(" ");#FloatTok("1.96");#SpecialCharTok("*");#NormalTok("se");],
[#NormalTok("  ), ");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.2");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_pubr");#NormalTok("()");],));
#align(center)[#box(image("05-ttests_files/figure-typst/unnamed-chunk-18-1.svg"))]
=== Assumption checks
<assumption-checks-1>
There are three main assumptions for a basic independent samples #emph[t]-test:

- Data must be independent of each other - in other words, one person's response should not be influenced by another. This should come as a feature of good experimental design.
- The equality of variance (homoscedasticity) assumption. The classical #emph[t]-test assumes that each group has the same variance (homoscedasticity). We can test this using a significant test called Levene's test. If the test is significant (#emph[p] \< .05), the assumption is violated. In our data, this assumption seems to be intact (#emph[F]\(1, 58) = .114, #emph[p] = .737).

#block[
#Skylighting(([#NormalTok("w8_training ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("levene_test");#NormalTok("(Years_training ");#SpecialCharTok("~");#NormalTok(" Group, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Warning in leveneTest.default(y = y, group = group, ...): group coerced to");],
[#NormalTok("factor.");],));
]
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 4");],
[#NormalTok("    df1   df2 statistic     p");],
[#NormalTok("  <int> <int>     <dbl> <dbl>");],
[#NormalTok("1     1    58     0.114 0.737");],));
]
]
- The residuals should be normally distributed. This essentially has implications for how well the data behaves. We can test this in two ways. The first is using a normality test, like the #strong[Shapiro-Wilks (SW)] test, which is usually done using #NormalTok("shapiro.test()");. Like Levene's test, if the result of this test is significant it suggests that the normality assumption is violated. The result that Jamovi gives is not super clear in terms of what values exactly have been used to run the SW-test, so we will turn to another method.

For an independent t-test specifically, another way of testing this assumption is to simply see whether the dependent variable is normally distributed in #strong[both groups separately]. In other words, we perform a Shapiro-Wilks test on years of training in both amateurs and professionals.

#NormalTok("rstatix"); provides its own version of the SW-test (#NormalTok("shapiro_test");) that is compatible with #NormalTok("group_by()"); and general tidyverse notation. Thus, we can first group using #NormalTok("group_by()");, and then run a SW-test on each group:

#block[
#Skylighting(([#NormalTok("w8_training ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(Group) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("shapiro_test");#NormalTok("(Years_training)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 2 × 4");],
[#NormalTok("  Group        variable       statistic       p");],
[#NormalTok("  <chr>        <chr>              <dbl>   <dbl>");],
[#NormalTok("1 Amateur      Years_training     0.901 0.00763");],
[#NormalTok("2 Professional Years_training     0.938 0.0896 ");],));
]
]
We can therefore see that for professionals our data is normally distribution (#emph[W] = .94, #emph[p] = .090), but not for amateurs (#emph[W] = .90, #emph[p] = .008).

=== Output
<output-3>
In reality, it's rare that any of these assumptions are fully met even when tests say they are (the tests we just mentioned can be biased). This is especially true for classical #emph[t]-tests, which are very sensitive to violations. A consistently better alternative is to use the Welch #emph[t]-test, which assumes the equality of variance assumption is not met. Welch #emph[t]-tests are also fairly robust against the normality assumption, and so are more flexible without sacrificing accuracy.

Here's our output from R. Note that this is from a Welch #emph[t]-test - R will do this by default.

#block[
#Skylighting(([#FunctionTok("t.test");#NormalTok("(Years_training ");#SpecialCharTok("~");#NormalTok(" Group, ");#AttributeTok("data =");#NormalTok(" w8_training)");],));
#block[
#Skylighting(([],
[#NormalTok("    Welch Two Sample t-test");],
[],
[#NormalTok("data:  Years_training by Group");],
[#NormalTok("t = -5.8586, df = 57.989, p-value = 2.33e-07");],
[#NormalTok("alternative hypothesis: true difference in means between group Amateur and group Professional is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" -3.922048 -1.924448");],
[#NormalTok("sample estimates:");],
[#NormalTok("     mean in group Amateur mean in group Professional ");],
[#NormalTok("                  4.387097                   7.310345 ");],));
]
#Skylighting(([#NormalTok("w8_training ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("t_test");#NormalTok("(Years_training ");#SpecialCharTok("~");#NormalTok(" Group, ");#AttributeTok("detailed =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 15");],
[#NormalTok("  estimate estimate1 estimate2 .y.   group1 group2    n1    n2 statistic       p");],
[#NormalTok("*    <dbl>     <dbl>     <dbl> <chr> <chr>  <chr>  <int> <int>     <dbl>   <dbl>");],
[#NormalTok("1    -2.92      4.39      7.31 Year… Amate… Profe…    31    29     -5.86 2.33e-7");],
[#NormalTok("# ℹ 5 more variables: df <dbl>, conf.low <dbl>, conf.high <dbl>, method <chr>,");],
[#NormalTok("#   alternative <chr>");],));
]
]
Now for the effect size. For an independent samples #emph[t]-test, you can give it #emph[almost] the same as the regular #NormalTok("t.test()"); function. The only change is that by default, #NormalTok("cohens_d()"); will calculate Cohen's #emph[d] assuming equal variance. In order for our value of #emph[d] to match a Welch-samples #emph[t]-test, we need to set #NormalTok("pooled_sd = FALSE"); (which makes the syntax slightly different to #NormalTok("t.test()");).

#block[
#Skylighting(([#CommentTok("# Independent samples");],
[#CommentTok("# t.test(Years_training ~ Group, data = w8_training)");],
[#NormalTok("effectsize");#SpecialCharTok("::");#FunctionTok("cohens_d");#NormalTok("(Years_training ");#SpecialCharTok("~");#NormalTok(" Group, ");#AttributeTok("data =");#NormalTok(" w8_training, ");#AttributeTok("pooled_sd =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Cohen's d |         95% CI");],
[#NormalTok("--------------------------");],
[#NormalTok("-1.51     | [-2.08, -0.93]");],
[],
[#NormalTok("- Estimated using un-pooled SD.");],));
]
]
Or again, we can alternatively use the #NormalTok("cohen_d()"); function from #NormalTok("rstatix");:

#block[
#Skylighting(([#NormalTok("w8_training ");#SpecialCharTok("%>%");],
[#NormalTok("  rstatix");#SpecialCharTok("::");#FunctionTok("cohens_d");#NormalTok("(Years_training ");#SpecialCharTok("~");#NormalTok(" Group, ");#AttributeTok("ci =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("ci.type =");#NormalTok(" ");#StringTok("\"norm\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 9");],
[#NormalTok("  .y.            group1  group2 effsize    n1    n2 conf.low conf.high magnitude");],
[#NormalTok("* <chr>          <chr>   <chr>    <dbl> <int> <int>    <dbl>     <dbl> <ord>    ");],
[#NormalTok("1 Years_training Amateur Profe…   -1.51    31    29    -2.09     -0.83 large    ");],));
]
]
From this, we can see that the two groups do significantly differ on years of training (#emph[t]\(57.99) = 5.86, #emph[p] \< .001). We can use the mean difference value to see, well… the difference in means between the two groups. In this case, professionals have 2.92 more years of training (on average; 95% CI = \[1.92, 3.92\]) compared to amateurs. So, we could write this up as something like:

#block(fill: rgb("#cce3c8"))[
An independent samples #emph[t]-test was conducted to examine whether professionals and amateurs differed on years of musical instrument training. Professionals had on average 2.92 years more training (95% CI \[1.92, 3.92\]) compared to amateurs (#emph[t]\(57.99) = 5.86, #emph[p] \< .001), corresponding to a large significant effect (#emph[d] = 1.51).

]
\(n.b.~the signs for #emph[t] and the mean difference don't overly matter so long as they are interpreted in the right way. The output above calculates amateurs - professionals, which is why the values for both are negative; but if you were to force the test to run the other way round, the values would be the same with the signs flipped. Hence why descriptives and graphs are super important too!)

If for some reason you do want R to run a Student's #emph[t]-test, you need to specify #NormalTok("var.equal = TRUE");. This tells R that we assume equality of variances.

#block[
#Skylighting(([#FunctionTok("t.test");#NormalTok("(Years_training ");#SpecialCharTok("~");#NormalTok(" Group, ");#AttributeTok("data =");#NormalTok(" w8_training, ");#AttributeTok("var.equal =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    Two Sample t-test");],
[],
[#NormalTok("data:  Years_training by Group");],
[#NormalTok("t = -5.8424, df = 58, p-value = 2.476e-07");],
[#NormalTok("alternative hypothesis: true difference in means between group Amateur and group Professional is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" -3.924805 -1.921691");],
[#NormalTok("sample estimates:");],
[#NormalTok("     mean in group Amateur mean in group Professional ");],
[#NormalTok("                  4.387097                   7.310345 ");],));
]
#Skylighting(([#NormalTok("w8_training ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("t_test");#NormalTok("(Years_training ");#SpecialCharTok("~");#NormalTok(" Group, ");#AttributeTok("detailed =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("var.equal =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 15");],
[#NormalTok("  estimate estimate1 estimate2 .y.   group1 group2    n1    n2 statistic       p");],
[#NormalTok("*    <dbl>     <dbl>     <dbl> <chr> <chr>  <chr>  <int> <int>     <dbl>   <dbl>");],
[#NormalTok("1    -2.92      4.39      7.31 Year… Amate… Profe…    31    29     -5.84 2.48e-7");],
[#NormalTok("# ℹ 5 more variables: df <dbl>, conf.low <dbl>, conf.high <dbl>, method <chr>,");],
[#NormalTok("#   alternative <chr>");],));
]
]
== Paired-samples #emph[t]-test
<paired-samples-t-test>
Here's our last test for the module, and it is again another bread-and-butter statistical test in literature: the paired-samples #emph[t]-test.

=== Paired-samples
<paired-samples>
Paired samples #emph[t]-tests, as the name sort of implies, are used when we have a sample and we take measurements twice. Often, paired-samples #emph[t]-tests are interested in testing the effect of time on an outcome; for example, a before-after design lends itself quite nicely to paired-samples and other repeated-measures tests.

The core hypotheses are very much the same here, aside from the caveat that the means are between conditions and not groups.

Mathematically, the paired-samples #emph[t]-test is actually just a variant of the one-sample #emph[t]-test. If we did a one-sample #emph[t]-test on the differences between the two timepoints/conditions, we would get the same results. You can see a demonstration of this in the dropdown at the end of this section.

=== Example data
<example-data-2>
For this example, we'll take a look at a simple interventions study. Participants were asked to answer a short list of questions relating to how they were feeling, once before an intervention and once afterwards. Higher scores represent better emotional states. The intervention was a series of self-regulation classes and exercises that the participants took twice a week. We're interested in seeing whether the intervention was effective.

#block[
#Skylighting(([#NormalTok("w8_symptoms ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_8\"");#NormalTok(", ");#StringTok("\"W8_symptoms.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 32 Columns: 2");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("dbl (2): before, after");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
#Skylighting(([#FunctionTok("head");#NormalTok("(w8_symptoms)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 2");],
[#NormalTok("  before after");],
[#NormalTok("   <dbl> <dbl>");],
[#NormalTok("1     14    18");],
[#NormalTok("2     18    17");],
[#NormalTok("3     14    18");],
[#NormalTok("4     10    18");],
[#NormalTok("5     14    12");],
[#NormalTok("6     14    13");],));
]
]
#block[
#callout(
body: 
[
Data for paired-samples #emph[t]-tests can either be in wide form or long form, and this depends on the specific function used. Our dataset is already in wide form as we have one column for before and one for after, so the following code will create a long-form version:

#block[
#Skylighting(([#CommentTok("# Pivot to long format");],
[#NormalTok("w8_symptoms_long ");#OtherTok("<-");#NormalTok(" w8_symptoms ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pivot_longer");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("cols =");#NormalTok(" ");#FunctionTok("everything");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("names_to =");#NormalTok(" ");#StringTok("\"time\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("values_to =");#NormalTok(" ");#StringTok("\"symptom_score\"");],
[#NormalTok("  )");],));
]
To check that this has worked properly, we can use #NormalTok("head()"); to do a quick check of the new data frame:

#block[
#Skylighting(([#CommentTok("# Display start of new data");],
[#FunctionTok("head");#NormalTok("(w8_symptoms_long)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 2");],
[#NormalTok("  time   symptom_score");],
[#NormalTok("  <chr>          <dbl>");],
[#NormalTok("1 before            14");],
[#NormalTok("2 after             18");],
[#NormalTok("3 before            18");],
[#NormalTok("4 after             17");],
[#NormalTok("5 before            14");],
[#NormalTok("6 after             18");],));
]
]
]
, 
title: 
[
R Note: Setting up your data for paired samples
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
If you run the code chunk in the box above, you will get a long version of our dataset. We can use this to generate a nice-looking plot quite easily, like before:

#Skylighting(([#NormalTok("w8_symptoms_long ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(time) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("n =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("mean_score =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(symptom_score, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("sd_score =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(symptom_score, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("se =");#NormalTok(" sd_score");#SpecialCharTok("/");#FunctionTok("sqrt");#NormalTok("(n)");],
[#NormalTok("  ) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("time =");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(time, ");#AttributeTok("levels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"before\"");#NormalTok(", ");#StringTok("\"after\"");#NormalTok("), ");],
[#NormalTok("                  ");#AttributeTok("labels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"Before\"");#NormalTok(", ");#StringTok("\"After\"");#NormalTok("))");],
[#NormalTok("  ) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" time, ");#AttributeTok("y =");#NormalTok(" mean_score)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("size =");#NormalTok(" ");#DecValTok("4");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_errorbar");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("ymin =");#NormalTok(" mean_score ");#SpecialCharTok("-");#NormalTok(" ");#FloatTok("1.96");#SpecialCharTok("*");#NormalTok("se,");],
[#NormalTok("    ");#AttributeTok("ymax =");#NormalTok(" mean_score ");#SpecialCharTok("+");#NormalTok(" ");#FloatTok("1.96");#SpecialCharTok("*");#NormalTok("se");],
[#NormalTok("  ), ");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.2");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_pubr");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Timepoint\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Mean symptom score\"");#NormalTok(")");],));
#align(center)[#box(image("05-ttests_files/figure-typst/unnamed-chunk-28-1.svg"))]
=== Assumption checks
<assumption-checks-2>
Similar to other tests, we need to check normality. Here, the assumption is whether the differences between time 1 and 2 are normally distributed (not necessarily time 1 and 2 themselves). Hence, when we run a Shapiro-Wilks test we're running this on the values we get from Time 1 - Time 2.

In our data, this assumption seems to be intact (#emph[W] .985, #emph[p] = .918).

#block[
#Skylighting(([#FunctionTok("shapiro.test");#NormalTok("(w8_symptoms");#SpecialCharTok("$");#NormalTok("before ");#SpecialCharTok("-");#NormalTok(" w8_symptoms");#SpecialCharTok("$");#NormalTok("after)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  w8_symptoms$before - w8_symptoms$after");],
[#NormalTok("W = 0.98465, p-value = 0.9177");],));
]
]
=== Output
<output-4>
In R, you can do pairwise #emph[t]-tests using the default #NormalTok("t.test()"); (or the #NormalTok("rstatix"); equivalent #NormalTok("t_test()");) function. In both methods, you must set #NormalTok("paired = TRUE"); in order to run a paired #emph[t]-test. However, there is one key difference: the base #NormalTok("t.test()"); requires data in #emph[wide] format, whereas #NormalTok("rstatix::t_test()"); requires data in #emph[long] format. Here are both methods.

For the base #NormalTok("t.test()"); function, your data needs to be in wide format. From there it is as simple as giving the two columns as the arguments to the function, and setting #NormalTok("paired = TRUE");:

#block[
#Skylighting(([#FunctionTok("t.test");#NormalTok("(");#AttributeTok("x =");#NormalTok(" w8_symptoms");#SpecialCharTok("$");#NormalTok("before, ");#AttributeTok("y =");#NormalTok(" w8_symptoms");#SpecialCharTok("$");#NormalTok("after, ");#AttributeTok("paired =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    Paired t-test");],
[],
[#NormalTok("data:  w8_symptoms$before and w8_symptoms$after");],
[#NormalTok("t = -2.9501, df = 31, p-value = 0.005999");],
[#NormalTok("alternative hypothesis: true mean difference is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" -4.651185 -0.848815");],
[#NormalTok("sample estimates:");],
[#NormalTok("mean difference ");],
[#NormalTok("          -2.75 ");],));
]
]
Alternatively, you can use the below notation. #NormalTok("Pair(before, after)"); indicates that we want R to treat the #NormalTok("before"); and #NormalTok("after"); variables as paired data. The #NormalTok("~ 1");, as we saw before, indicates that this is a one-sample #emph[t]-test. This is because a paired-samples #emph[t]-test is functionally equivalent to a one-sample #emph[t]-test on the differences between conditions (see the expandable dropdown below for more details).

#block[
#Skylighting(([#FunctionTok("t.test");#NormalTok("(");#FunctionTok("Pair");#NormalTok("(before, after) ");#SpecialCharTok("~");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("data =");#NormalTok(" w8_symptoms)");],));
#block[
#Skylighting(([],
[#NormalTok("    Paired t-test");],
[],
[#NormalTok("data:  Pair(before, after)");],
[#NormalTok("t = -2.9501, df = 31, p-value = 0.005999");],
[#NormalTok("alternative hypothesis: true mean difference is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" -4.651185 -0.848815");],
[#NormalTok("sample estimates:");],
[#NormalTok("mean difference ");],
[#NormalTok("          -2.75 ");],));
]
]
Note that before R 4.4.0 (2024), the notation for paired-samples #emph[t]-tests were different.

If you prefer #NormalTok("rstatix");, on the other hand, your data needs to be in long format. After that, you can pass the test as a formula much like how you would do so in the independent samples case:

#block[
#Skylighting(([#NormalTok("w8_symptoms_long ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("t_test");#NormalTok("(symptom_score ");#SpecialCharTok("~");#NormalTok(" time, ");#AttributeTok("paired =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("detailed =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 13");],
[#NormalTok("  estimate .y.          group1 group2    n1    n2 statistic     p    df conf.low");],
[#NormalTok("*    <dbl> <chr>        <chr>  <chr>  <int> <int>     <dbl> <dbl> <dbl>    <dbl>");],
[#NormalTok("1     2.75 symptom_sco… after  before    32    32      2.95 0.006    31    0.849");],
[#NormalTok("# ℹ 3 more variables: conf.high <dbl>, method <chr>, alternative <chr>");],));
]
]
Once again, we'll also want to calculate Cohen's #emph[d] for our paired-samples #emph[t]-test. For a paired-samples #emph[t]-test the developers of #NormalTok("effectsize"); recommend using the #NormalTok("rm_d()"); function, which stands for repeated-measures Cohen's #emph[d]. This function takes the same basic syntax as #NormalTok("t.test()"); for paired-samples #emph[t]-tests, including the use of wide data, but a couple of extra arguments are required.

- #NormalTok("method = \"z\""); defines how the pooled SD term is calculated. There are six possible options, but this option gives the standard calculation.
- #NormalTok("adjust = FALSE");: calculates Hedges' G, which is an alternative effect size that corrects for small sample bias. We won't worry about this here, so we will set this to #NormalTok("FALSE");.

Note that like the other functions, you can either provide the arguments in #NormalTok("Pairs() ~ 1"); or by subsetting the columns (#NormalTok("x = x$1, y = x$2");).

#block[
#Skylighting(([#CommentTok("# Paired sample - works with wide data");],
[#CommentTok("# t.test(Pair(before, after) ~ 1, data = w8_symptoms)");],
[#NormalTok("effectsize");#SpecialCharTok("::");#FunctionTok("rm_d");#NormalTok("(");#FunctionTok("Pair");#NormalTok("(before, after) ");#SpecialCharTok("~");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("data =");#NormalTok(" w8_symptoms, ");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"z\"");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("d (z) |         95% CI");],
[#NormalTok("----------------------");],
[#NormalTok("-0.52 | [-0.89, -0.15]");],));
]
]
#block[
#Skylighting(([#CommentTok("# t.test(x = w8_symptoms$before, y = w8_symptoms$after, paired = TRUE)");],
[#NormalTok("effectsize");#SpecialCharTok("::");#FunctionTok("rm_d");#NormalTok("(");#AttributeTok("x =");#NormalTok(" w8_symptoms");#SpecialCharTok("$");#NormalTok("before, ");#AttributeTok("y =");#NormalTok(" w8_symptoms");#SpecialCharTok("$");#NormalTok("after, ");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"z\"");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("d (z) |         95% CI");],
[#NormalTok("----------------------");],
[#NormalTok("-0.52 | [-0.89, -0.15]");],));
]
]
If using #NormalTok("cohen_d");\() from #NormalTok("rstatix");, #NormalTok("paired = TRUE"); must be selected:

#block[
#Skylighting(([#NormalTok("w8_symptoms_long ");#SpecialCharTok("%>%");],
[#NormalTok("  rstatix");#SpecialCharTok("::");#FunctionTok("cohens_d");#NormalTok("(symptom_score ");#SpecialCharTok("~");#NormalTok(" time, ");#AttributeTok("paired =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("ci =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("ci.type =");#NormalTok(" ");#StringTok("\"norm\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 9");],
[#NormalTok("  .y.           group1 group2 effsize    n1    n2 conf.low conf.high magnitude");],
[#NormalTok("* <chr>         <chr>  <chr>    <dbl> <int> <int>    <dbl>     <dbl> <ord>    ");],
[#NormalTok("1 symptom_score after  before   0.522    32    32      0.1      0.89 moderate ");],));
]
]
The Canvas version asks you to interpret each of these effect sizes, but… #NormalTok("rstatix"); will automatically label this for you!

The mean symptom scores of the two timepoints are significantly different (#emph[t]\(31) = 2.95, #emph[p] = .006). Based on the means and mean difference (2.75; 95% CI = \[0.85, 4.65\]), participants reported having significantly better emotional states after the intervention compared to beforehand. We can write that up as below, and in this specific example we will condense the text down:

#block(fill: rgb("#cce3c8"))[
A paired samples #emph[t]-test found that symptoms significantly decreased after the intervention (#emph[t]\(31) = 2.95, #emph[p] = .006), with an average decrease of 2.75 points (95% CI \[0.85, 4.65\]). This decrease was medium in size (#emph[d] = 0.52).

]
#block[
#callout(
body: 
[
Mathematically, all a paired-samples #emph[t]-test is doing is running a one-sample #emph[t]-test on the differences between the two timepoints/groups, Below is a demonstration of how paired-samples tests can be run using the one-sample #emph[t]-test.

Let's start by returning to the wide version of our dataset. We first need to calculate the difference between the #NormalTok("before"); and #NormalTok("after"); columns, which we can easily do with #NormalTok("mutate()");.

#block[
#Skylighting(([#NormalTok("w8_symptoms ");#OtherTok("<-");#NormalTok(" w8_symptoms ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("diff =");#NormalTok(" before ");#SpecialCharTok("-");#NormalTok(" after");],
[#NormalTok("  )");],
[],
[#NormalTok("w8_symptoms");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 32 × 3");],
[#NormalTok("   before after  diff");],
[#NormalTok("    <dbl> <dbl> <dbl>");],
[#NormalTok(" 1     14    18    -4");],
[#NormalTok(" 2     18    17     1");],
[#NormalTok(" 3     14    18    -4");],
[#NormalTok(" 4     10    18    -8");],
[#NormalTok(" 5     14    12     2");],
[#NormalTok(" 6     14    13     1");],
[#NormalTok(" 7     11    20    -9");],
[#NormalTok(" 8     12    18    -6");],
[#NormalTok(" 9     15    18    -3");],
[#NormalTok("10     18     8    10");],
[#NormalTok("# ℹ 22 more rows");],));
]
]
We can run a one-sample #emph[t]-test on the differences now, with the null hypothesis value being 0 - i.e.~we are testing the null hypothesis that the differences between the two timepoints are not significantly different from 0.

#block[
#Skylighting(([#FunctionTok("t.test");#NormalTok("(w8_symptoms");#SpecialCharTok("$");#NormalTok("diff ");#SpecialCharTok("~");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("mu =");#NormalTok(" ");#DecValTok("0");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    One Sample t-test");],
[],
[#NormalTok("data:  w8_symptoms$diff");],
[#NormalTok("t = -2.9501, df = 31, p-value = 0.005999");],
[#NormalTok("alternative hypothesis: true mean is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" -4.651185 -0.848815");],
[#NormalTok("sample estimates:");],
[#NormalTok("mean of x ");],
[#NormalTok("    -2.75 ");],));
]
]
As we can see, the results are equivalent to the output of the paired-samples #emph[t]-test above. Note too that our Shapiro-Wilks test will also give equivalent results if it is run on the differences directly.

]
, 
title: 
[
Paired samples using the one-sample #emph[t]-test
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
= ANOVAs
<anovas>
#emph[t]-tests, as we saw last week, were a simple way of comparing a continuous outcome between two groups or conditions (i.e.~one categorical variable with two levels). However, it's also common to compare across three or more groups when doing real research. To test this kind of hypothesis where we have three or more groups, we need to turn to a different method - the ANOVA. ANOVAs are useful when you have one categorical IV with 3+ levels, and one continuous DV.

The ANOVA is perhaps one of the most common statistical tests you will see in music psychology literature, in part because they generalise to a lot of research designs. In many respects, this week is fairly important in terms of knowing how to conduct an ANOVA and when. We'll only be stepping through the basics this week, but there are some really important fundamentals to cover here.

It's also common to analyse two independent variables against one dependent variable. These too can be done using ANOVAs. While we won't go into this in this module, there will be an Extension Module that deals with this separately - check it out sometime around Week 10/11 if you're interested.

By the end of this module you should be able to:

- Understand and describe the conceptual basis of an analysis of variance
- Describe how an ANOVA is calculated
- Conduct both one-way ANOVAs and one-way repeated ANOVAs, including their assumption tests
- Interpret the output of the ANOVAs and report their findings

#figure([
#box(image("index_files\\mediabag\\third_way_2x.png"))
], caption: figure.caption(
position: bottom, 
[
#link("https://xkcd.com/1285/")[xkcd: Third Way]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


== Anovas and the #emph[F]-distribution
<anovas-and-the-f-distribution>
#block(fill: rgb("#f5f5f5"))[
Just as we've done so for chi-squares and #emph[t]-tests, let's begin with an overview of the mathematical and conceptual underpinnings of the ANOVA.

]
=== The basic logic of ANOVAs
<the-basic-logic-of-anovas>
As we said in the introductory page, ANOVA stands for #strong[AN]alysis #strong[O]f #strong[VA]riance. This essentially sums up how an ANOVA works in principle. ANOVAs can be used when analysing a categorical IV with two or more groups (typically 3+) and a continuous DV. As the setup suggests, ANOVAs are a good way of comparing different groups on a singular outcome.

The most basic hypotheses for an ANOVA center around whether or not the means between groups are significantly different, i.e.:

- $H_0$: The means between groups are not significantly different. (i.e.~$mu_1 = mu_2 = . . . mu_k$)
- $H_1$: The means between groups are significantly different. (i.e.$mu_1 eq.not mu_2 eq.not . . . mu_k$)

How do we test for this? The basic logic of the ANOVA is this: Whenever we have data that we categorise into different groups, we end up with two key sources of variability, or variance: variance that exists between groups, and variance that exists within groups:

#box(image("06-anovas_files/figure-typst/unnamed-chunk-3-1.svg"))

Pretend that the three curves above represent data covering three different groups, and that we've hypothesised that there are three different means. Collectively, this data has a certain amount of variance.

The first fundamental to recognise is that this total variance can be broken down into variance between groups and variance within groups:

$ V a r i a n c e_(t o t a l) = V a r i a n c e_(b e t w e e n) + V a r i a n c e_(w i t h i n) $

The variability between the groups would simply be the variance between the blue curve and the orange curve - in other words, how far apart the two sets of data are (in a simplistic sense). The within-group variance, on the other hand, is how much variance there is within each curve. If there is a lot of within-group variance within each curve, that would mean that (thinking back to Module 5) each group's curve would be spread widely.

If you're following the logic of this so far, the consequences of high within-group variance might be obvious - the two curves would significantly overlap. In contrast, if the between-group variance is far higher than the within-group variance, the curves may not overlap much at all - suggesting that the means of the two groups really are different.

This forms the basis of the ANOVA's #emph[F]-test, which is a ratio of variance:

$ F = frac(V a r i a n c e_(b e t w e e n), V a r i a n c e_(w i t h i n)) $

We will see this more in practice on the next page, but the #emph[F]-statistic, which we use as part of significance testing in ANOVAs, is calculated by simply dividing the between-group variance by the within-group variance.

=== The #emph[F]-distribution
<the-f-distribution>
Like the other tests we've encountered so far, ANOVAs have their own underlying distribution. In this instance, this is the #emph[F] distribution, which describes how the #emph[F]-statistic behaves. We won't go far into the maths around this, but the key here is that the #emph[F] distribution is characterised by two sets of degrees of freedom: one that relates to the between-groups variance/effect, and one that relates to the within-groups variance. One thing to note here is the terminology in the headers of each graph: the first number in the brackets refers to the between-groups variance, while the second number refers to the within-groups variance.

#box(image("06-anovas_files/figure-typst/unnamed-chunk-4-1.svg"))

=== #emph[F]-statistic tables
<f-statistic-tables>
And, once again, we have a special #emph[F]-table to determine critical #emph[F] values, given two degrees of freedom values. However, given that we have two degrees of freedom the process is a little bit more complicated. Most #emph[F]-stat tables actually provide multiple tables, corresponding to different alpha levels. For now, we will always use the table corresponding to alpha = 0.05, a snippet of which is below:

#Skylighting(([#NormalTok("knitr");#SpecialCharTok("::");#FunctionTok("include_graphics");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"img/w9_f-table.png\"");#NormalTok("))");],));
#box(image("img/w9_f-table.png"))

To read this table, you need to know both degrees of freedom (more on how to find that on the next page). The columns, marked df1, refer to the first df value (between-groups), while the rows correspond to the second df value (within-groups).

So, for example, if we have an #emph[F]-test with degrees of freedom of (4, 10), we would first need to find the column that corresponds to 4 (our df1), and then the row that corresponds to df2 = 10. Reading the cell at the intersection would give us a critical #emph[F]-statistic of 3.48; this is the value our #emph[F]-statistic would need to be greater than to be significant at the #emph[p] \< .05 level.

== The ANOVA table
<the-anova-table>
#block(fill: rgb("#f5f5f5"))[
Every time we do an ANOVA, there are actually a raft of calculations that have to occur in order to get our test statistic and #emph[p]-value. Statistical software will display all of this in the form of an ANOVA table, which we cover below.

Don't stress too much about the maths here - while the quiz does include one question about this, the question itself isn't difficult (and you won't be expected to do any of this by hand otherwise). The reason why we go through this, however, is to demonstrate the conceptual logic from the previous page.

]
=== The ANOVA table
<the-anova-table-1>
On the previous page, we talked in depth about how the #emph[F] statistic is calculated, and what shapes the overall distribution. But how do we actually calculate all of that stuff to begin with from raw data? Enter the ANOVA table, a beautiful (remember, beauty is subjective) way of calculating this information and laying it all out to see.

The basic ANOVA table looks like this, which you will see on any statistical package you use.

#table(
  columns: (16.67%, 16.67%, 16.67%, 16.67%, 16.67%, 16.67%),
  align: (auto,auto,auto,auto,auto,auto,),
  table.header([], [Sums of squares (SS)], [Degrees of freedom (df)], [Mean square (MS)], [F], [#emph[p]],),
  table.hline(),
  [Group (our effect)], [], [], [], [], [],
  [Error/Residual], [], [], [], [], [],
  [Total], [], [], [], [], [],
)
A couple of terminology-related things here.

- 'Group' in this context is our independent variable (i.e.~the effect of group)- this is our between-subject variance.
- 'Error' or 'Residual' is the within-group variance.

Let's use the below data to calculate this by hand.

#table(
  columns: 3,
  align: (left,left,left,),
  table.header([Group 1], [Group 2], [Group 3],),
  table.hline(),
  [1], [2], [5],
  [2], [4], [8],
  [3], [5], [6],
  [2], [3], [7],
  [Mean: 2], [Mean: 3.5], [Mean: 6],
)
The grand mean (i.e.~the mean across all 12 pieces of data) is 4. Keep this in mind.

Time to strap in - there are a lot of formulae involved!

=== Sums of squares
<sums-of-squares>
The sum of squares quantifies how far each observation is from the average - just like how it is calculated in the formula for standard deviations. For an ANOVA, we have two sets of SS to calculate - one for the between-groups term, and one for the within-groups/error.

#strong[Between]

The formula for the between-groups sum of squares ($S S_b$) is:

$ S S_b = Sigma n \( macron(x) - macron(X) \)^2 $

In words, this means:

- Take each group's mean ($macron(x)$), and subtract them from the grand mean ($macron(X)$)
- Square that difference
- Multiply it by n, the size of each group
- Add them all up.

Let's do that for our fictional data. Our group means are Group 1 = 2, Group 2 = 3.5 and Group 3 = 6.5. $ S S_b = 4 \( 2 - 4 \)^2 + 4 \( 3.5 - 4 \)^2 + 4 \( 6.5 - 4 \)^2 $

$ S S_b = \( 4 times 4 \) + \( 4 times 0.25 \) + \( 4 times 6.25 \) $ $ S S_b = 42 $

#strong[Within]

For the within-group sum of squares, the formula is:

$ S S_w = Sigma \( x - macron(x) \)^2 $

This one is a bit more tedious. It means:

- Take each observation ($x$), and subtract them from their group mean ($macron(x)$)
- Square that difference
- Add them all up.

So for our data, it would look something like.. $ S S_w = \( 1 - 2 \)^2 + \( 2 - 2 \)^2 + \( 3 - 2 \)^2 + \( 2 - 2 \)^2 +\
\( 2 - 3.5 \)^2 + \( 4 - 3.5 \)^2 + \( 5 - 3.5 \)^2 + \( 3 - 3.5 \)^2 +\
\( 5 - 6.5 \)^2 + \( 8 - 6.5 \)^2 + \( 6 - 6.5 \)^2 + \( 7 - 6.5 \)^2 $ $ S S_w = 12 $.

=== Degrees of freedom
<degrees-of-freedom>
Because we have a term for between-groups and within-groups effects, we also have degrees of freedom for both (think back to the previous page). Thankfully, unlike the mess above the formulae here are relatively simple.

#strong[Between]

The between-groups df is given as:

$ d f_b = k - 1 $

Where k = the number of groups. So, in our data, $d f_b = 3 - 1 = 2$ (as we have 3 groups).

#strong[Within]

The within-groups df is given as:

$ d f_b = N - k $

Where k = the number of groups, and #emph[N] is the total sample size (in our case, 12). So $d f_w = 12 - 3 = 9$ (as we have 3 groups and 12 data points in total).

=== Mean squares
<mean-squares>
The mean squares is another value for variance that essentially standardises the sum of squares by the degrees of freedom. The formula for MS between and within is the same:

$ M S = frac(S S, d f) $

We've calculated SS and df for both our between and within-groups effects, so we can substitute these values in to calculate a mean square value for both:

$ M S_b = frac(S S_b, d f_b) $ $ M S_w = frac(S S_w, d f_w) $

Putting in our values that we calculated earlier, we get:

$ M S_b = 42 / 2 $ $ M S_w = 12 / 9 $

This gives us $M S_b = 21$ and $M S_w = 1.33$.

=== Calculating #emph[F]
<calculating-f>
Remember on the previous page, how we talked about the #emph[F]-statistic being a ratio between two variances (between divided by within)? That's exactly what we're going to do next, using our calculated mean-square values:

$ F = frac(M S_b, M S_w) $

This gives us:

$ F = 21 / 1.33 = 15.75 $

=== Putting it all together
<putting-it-all-together>
Phew! Now we've calculated everything we need to for our ANOVA - in essence, we've done the majority of the ANOVA by hand. Let's put all of our values into the table below:

#table(
  columns: (21.11%, 23.33%, 26.67%, 18.89%, 6.67%, 3.33%),
  align: (left,left,left,left,left,left,),
  table.header([], [Sums of squares (SS)], [Degrees of freedom (df)], [Mean square (MS)], [F], [p],),
  table.hline(),
  [Group (our effect)], [42], [2], [21], [15.75], [],
  [Error/Residual], [12], [9], [1.33], [], [],
  [Total], [54], [], [], [], [],
)
Before we move on, it's also worth noting that $S S_b + S S_w = S S_(t o t a l)$ \; this goes back to the fundamental we discussed on the previous page, where an ANOVA breaks down total variance into between and within-groups variance.

=== Consulting the #emph[F]-table
<consulting-the-f-table>
Now that we have our observed #emph[F]-value, we can now consult an #emph[F]-table and use our two degrees of freedom to find out what our critical #emph[F]-value is (setting alpha = .05):

#box(image("img/w9_f-table.png"))

Reading the column for df1 = 2, and the row for df2 = 9, we get a critical #emph[F]-statistic of 4.2565. Now we can say that because our observed test statistic (15.75) is greater than this critical value, our ANOVA is significant at the alpha = .05 level.

In reality, like many of the other tests, we would calculate a #emph[p]-value by observing where our test statistic falls on the #emph[F]-distribution, and the associated probability of getting that value or greater. Our software will do all of this stuff for us, but it helps to know exactly how an ANOVA works!

If you want to calculate the #emph[p]-value manurally in R though, this is entirely possible using the #NormalTok("pf()"); function:

#block[
#Skylighting(([#FunctionTok("pf");#NormalTok("(");#AttributeTok("q =");#NormalTok(" ");#FloatTok("15.75");#NormalTok(", ");#AttributeTok("df1 =");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#AttributeTok("df2 =");#NormalTok(" ");#DecValTok("9");#NormalTok(", ");#AttributeTok("lower.tail =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 0.001149592");],));
]
]
== Multiple comparisons
<multiple-comparisons>
#block(fill: rgb("#f5f5f5"))[
On this page we talk about what happens after a significant ANOVA result, as well as some more detail about the multiple comparisons problem, and how it can be accounted for.

]
=== Post-hoc tests
<post-hoc-tests>
The ANOVA table on the previous page allows us to calculate by hand whether there is a significant effect of our IV. However, it doesn't tell us where that difference lies. Remember, we're comparing at least three groups with each other - so we need some way of figuring out where the actual significant differences between means are.

Enter post-hoc comparisons (post-hoc = after the fact). These are essentially a series of #emph[t]-tests where we compare each group with each other. So, if we have groups A, B and C, and we get a significant omnibus ANOVA that tells us there is a significant difference somewhere in those means, we would run post-hoc comparisons by running individual #emph[t]-tests on A vs B, then B vs C, then A vs C.

However, we can't just do this blindly, and there's a good reason why…

=== The multiple comparisons problem
<the-multiple-comparisons-problem>
In Module 6, we talked a fair bit about Type I and II error rates - i.e., the rate of making a false positive and false negative judgement respectively. Here, we'll focus on Type I error.

Recall that whenever we do a hypothesis test, we set a value for alpha, which forms our significance level. Alpha is essentially the probability of Type I errors we are willing to accept in a given test. In other words, when we use the conventional alpha = .05 as our criterion for significance, we are saying that we're willing to accept a Type I error occurring 5% of the time - or 1 in 20.

This becomes problematic when we have to conduct multiple tests at once, like what we have to do in an ANOVA. For example, let's say a variable has 5 levels - A, B, C, D and E. If we ran an ANOVA on this data and found a significant omnibus effect, we would want to find out where that effect is. But that means that we'd have to compare A, B, C, D and E all against each other, in a round-robin tournament way (e.g.~A vs B, then A vs C…). Where this becomes an issue is that each comparison will have its own 5% Type I error rate (assuming we use alpha = .05). So in this scenario, the Type I error rate will stack with each new comparison, meaning that our overall Type I error rate will climb higher and higher. This means that the chance of finding a false positive will increase (see graph below).

#align(center)[#box(image("06-anovas_files/figure-typst/unnamed-chunk-11-1.svg"))]
This overall rate of Type I errors is called the family-wise error rate (FWER). 'Family' in this context refers to a family of comparisons - like the comparison across A to E that we saw above.

=== Correction methods
<correction-methods>
One way of dealing with this is to correct the #emph[p]-values to set the family-wise error rate back to 5%. We'll go through three main types (two of which are already covered in the seminar).

#strong[Tukey's HSD]

Tukey's Honest Significant Differences (Tukey HSD for short) is appropriate specifically for post-hoc tests after ANOVAs. It essentially works by first calculating the largest possible difference between each group's means, then using that to calculate a critical mean difference. Any mean difference that is greater than this critical threshold is significant.

#block[
#callout(
body: 
[
Tukey's HSD works very similarly in principle to a #emph[t]-test, although the exact maths involved are slightly different. The test statistic for a Tukey test is called #emph[q] which denotes the Studentized range distribution (a specific distribution). For a given comparison between two group means, the formula for #emph[q] is:

$ q = frac(\| M_1 - M_2 \|, S E) $

Where $M_1$ and $M_2$ denote the means of groups 1 and 2, and SE denotes the standard error of the sum of the means. The #emph[q]-statistic is then compared to a Studentized range distribution to estimate a p-value for that comparison. The shape of the Studentized range distribution is determined by alpha, #emph[k] (the number of groups being compared) and #emph[df] (in this case, the \*\*error degrees of freedom\*\*\*).

]
, 
title: 
[
How does the Tukey test work?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#strong[Bonferroni]

The Bonferroni correction is a method that can be used both within ANOVAs and in more general contexts. The Bonferroni correction works by multiplying each #emph[p]-value in a set of comparisons by the number of comparisons (i.e.~the number of #emph[p]-values).

For example, if a set of comparisons gives the following #emph[p]-values: 0.05, 0.25 and 0.10, we would apply a Bonferroni correction by multiplying each #emph[p]-value by 3 (as there are 3 #emph[p]-values) to get 0.15, 0.75 and 0.30 respectively.

\(Note: in reality, Bonferroni works by dividing alpha by the number of comparisons, i.e.~0.05/3 - but for the purpose of significance testing, the maths works out to be the same).

#strong[Holm]

The Holm correction is another correction method. In this method, each #emph[p]-value is first ranked from smallest to largest. and then numbered in a descending fashion. Using the same #emph[p]-values as above, we would get 0.05, 0.10 and 0.25. The #emph[p] = .05 would be ranked as 3, the #emph[p] = .10 would be 2 and #emph[p] = .25 would be 1.

You then multiply the #emph[p]-value by its rank, like the table below, to get your adjusted #emph[p]-values:

#table(
  columns: 4,
  align: (left,left,left,left,),
  table.header([Original p-value], [Sorted p-value], [Rank], [p-value x rank],),
  table.hline(),
  [0.05], [0.05], [3], [0.15],
  [0.25], [0.10], [2], [0.20],
  [0.10], [0.25], [1], [0.25],
)
The Bonferroni procedure is very conservative, in that it may actually overcorrect (and subsequently reject too many); the Holm correction still corrects the overall FWER without also increasing the overall Type II rate as well.

=== Post-hocs in R
<post-hocs-in-r>
To just get adjusted #emph[p]-values, we can use the function #NormalTok("pairwise.t.test()");. This needs three arguments:

+ #NormalTok("x"); refers to the column of data for the outcome, expressed as #NormalTok("data$x");.
+ #NormalTok("g"); refers to the group/IV, again as #NormalTok("data$g");.
+ #NormalTok("p.adjust.method"); refers to the adjustment method. Note this argument does not allow Tukey adjustments: only Bonferroni and Holm are allowed.

#block[
#Skylighting(([#FunctionTok("pairwise.t.test");#NormalTok("(");#AttributeTok("x =");#NormalTok(" w9_slices");#SpecialCharTok("$");#NormalTok("rating, ");#AttributeTok("g =");#NormalTok(" w9_slices");#SpecialCharTok("$");#NormalTok("group, ");#AttributeTok("p.adjust.method =");#NormalTok(" ");#StringTok("\"bonferroni\"");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    Pairwise comparisons using t tests with pooled SD ");],
[],
[#NormalTok("data:  w9_slices$rating and w9_slices$group ");],
[],
[#NormalTok("        caramel lemon ");],
[#NormalTok("lemon   0.6866  -     ");],
[#NormalTok("vanilla 0.0541  0.0017");],
[],
[#NormalTok("P value adjustment method: bonferroni ");],));
]
]
A more powerful and flexible method is using the #NormalTok("emmeans"); package. #NormalTok("emmeans"); stands for estimated marginal means, which are model-derived estimates of each group's mean. Simple effects tests are generally run on the estimate marginal means, and thus this package allows us a handy way to run these comparisons.

There are two steps to using #NormalTok("emmeans");:

+ Define the estimated marginal means for the post-hocs.

This is simple to do. We call the #NormalTok("emmeans()"); function, which will set up all comparisons for the post-hoc. This function needs two arguments at minimum:

- The #NormalTok("aov"); model name, and
- The variable (i.e.~the groups) from which you are comparing levels against. This is given as #NormalTok("~ group");, where group denotes our IV.

Imagine an ANOVA model named #NormalTok("model_aov");, with variable #NormalTok("A"); that defines the groups in our ANOVA. Our first step would be to set up the comparisons using #NormalTok("emmeans()"); like below:

#block[
#Skylighting(([#NormalTok("model_em ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("emmeans");#NormalTok("(model_aov, ");#SpecialCharTok("~");#NormalTok(" A)");],));
]
#block[
#set enum(numbering: "1.", start: 2)
+ Generate pairwise comparisons for the post-hoc.
]

Continuing on from the example above, we can use the #NormalTok("pairs()"); function on our EM object, #NormalTok("model_em");, to run the post-hocs. #NormalTok("infer = TRUE"); will generate confidence intervals for the difference in EM means. By default this will be set at 95% confidence, which is typically what we want.

#block[
#Skylighting(([#FunctionTok("pairs");#NormalTok("(model_em, ");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
]
If we want to adjust the #emph[p]-values at this stage, we can give #NormalTok("pairs()"); an additional argument #NormalTok("adjust");, with the name of the adjustment method as a string. #NormalTok("pairs()"); will let you use Tukey, Bonferroni and Holm adjustments.

#block[
#Skylighting(([#FunctionTok("pairs");#NormalTok("(model_em, ");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#StringTok("\"holm\"");#NormalTok(")");],));
]
Optionally, to do this all in one go we could simply pipe from #NormalTok("emmeans()"); to #NormalTok("pairs()"); as follows:

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(model_aov, ");#SpecialCharTok("~");#NormalTok(" A) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#StringTok("\"holm\"");#NormalTok(")");],));
]
== Eta-squared
<eta-squared>
#block(fill: rgb("#f5f5f5"))[
Time to go over a new effect size measure! This time, we use eta-squared ($eta^2$) as an effect size for ANOVAs.

]
=== Eta-squared and variance
<eta-squared-and-variance>
At the start of this module, we introduced the concept of how ANOVA partitions total variance into both between and within-subject variance:

$ V a r i a n c e_(t o t a l) = V a r i a n c e_(b e t w e e n) + V a r i a n c e_(w i t h i n) $

This partitioning allows for a simple but important way of calculating effect sizes for ANOVAs. If we're interested in the effect of our IV (group, which is between-subject variance), we simply need to know how much of the total variance is explained by this variable.

This is #strong[eta-squared] ($eta^2$), our effect size for ANOVAs. Eta-squared gives us a #strong[percentage of how much variance in the DV can be attributed to the IV]. So an eta-squared of .778 means that 77.8% of the total variance in the outcome variable/DV is because of the IV variable/main effect. It is calculated as follows:

$ eta^2 = frac(S S_(e f f e c t), S S_t) $

In other words, we divide the sum of squares for the main effect by the total sum of squares. For repeated-measures ANOVAs, the formula is the same in practice (i.e.~divide the SS in the top row in the ANOVA table by the total).

A related version of this is #strong[partial eta-squared] ($eta_p^2$). This describes the effect of the IV #emph[after] accounting for the variance explained by other factors. This is not so relevant for one-way designs - regular and partial eta-squared will give the same answer - but becomes more relevant when you move into factorial designs where you have more than one IV.

The formula for partial eta-squared is:

$ eta_p^2 = frac(S S_(e f f e c t), S S_(e f f e c t) + S S_(e r r o r)) $

Where $S S_(e r r o r)$ is the sums of squares for the error/residual term in an ANOVA. In general, it's good practice to default to at least reporting partial eta-squared. Again, in a one-way ANOVA this will give the same answer as regular eta-squared, but in a factorial design (where you have more than one IV) it will give a more precise estimate of each variable's effect size.

One more variant you will see is #emph[generalised] eta-squared $eta_g^2$, which is similar to the partial variant. While partial eta-squared is great, it is sensitive to design - in other words, what variables are included in the analysis will influence the calculation of $eta_p^2$, meaning that it is only really comparable across studies of similar design. However, not every design will manipulate every predictor (e.g.~gender), and so generalised eta-squared ($eta_G^2$) can handle this. This effect size is best used in meta-analyses.

To calculate eta-squared using R, there are two ways as per usual. The first is by using tthe #NormalTok("anova_test()"); function in #NormalTok("rstatix");. By default, #NormalTok("anova_test()"); (and other ANOVA-related packages in R) will calculate #emph[generalised] eta squared (labelled #NormalTok("ges"); in the output). If you want partial eta-squared, you just need to give #NormalTok("anova_test()"); the extra argument #NormalTok("effect.size = \"pes\""); as follows:

#block[
#Skylighting(([#NormalTok("w9_memory ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("anova_test");#NormalTok("(");#AttributeTok("dv =");#NormalTok(" memory_score, ");#AttributeTok("wid =");#NormalTok(" Participant, ");#AttributeTok("within =");#NormalTok(" time, ");#AttributeTok("effect.size =");#NormalTok(" ");#StringTok("\"pes\"");#NormalTok(") ");],));
#block[
#Skylighting(([#NormalTok("ANOVA Table (type III tests)");],
[],
[#NormalTok("$ANOVA");],
[#NormalTok("  Effect DFn DFd       F        p p<.05   pes");],
[#NormalTok("1   time   2 188 132.625 1.19e-36     * 0.585");],
[],
[#NormalTok("$`Mauchly's Test for Sphericity`");],
[#NormalTok("  Effect     W     p p<.05");],
[#NormalTok("1   time 0.939 0.054      ");],
[],
[#NormalTok("$`Sphericity Corrections`");],
[#NormalTok("  Effect   GGe       DF[GG]    p[GG] p[GG]<.05   HFe       DF[HF]    p[HF]");],
[#NormalTok("1   time 0.943 1.89, 177.21 1.05e-34         * 0.961 1.92, 180.72 2.45e-35");],
[#NormalTok("  p[HF]<.05");],
[#NormalTok("1         *");],));
]
]
Note that as mentioned above, partial eta-squared and regular eta-squared are equivalent in a one-way ANOVA of any kind, so using this is ok.

Otherwise, our trusty #NormalTok("effectsize"); package provides functions for calculating effect sizes in R. We use a function called - you guessed it - #NormalTok("eta_squared()");. This function works in very much the same way as the other #NormalTok("effectsize"); family of functions do - you need to give them an anova model to calculate effect sizes for.

Here is an example with a one-way ANOVA, which we will look at on the next page:

#block[
#Skylighting(([#FunctionTok("eta_squared");#NormalTok("(w9_slices_aov, ");#AttributeTok("alternative =");#NormalTok(" ");#StringTok("\"two.sided\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("For one-way between subjects designs, partial eta squared is equivalent");],
[#NormalTok("  to eta squared. Returning eta squared.");],));
]
#block[
#Skylighting(([#NormalTok("# Effect Size for ANOVA");],
[],
[#NormalTok("Parameter | Eta2 |       95% CI");],
[#NormalTok("-------------------------------");],
[#NormalTok("group     | 0.19 | [0.03, 0.35]");],));
]
]
=== An example
<an-example>
Here's the ANOVA table we worked out by hand in Section 9.3:

#table(
  columns: (21.11%, 23.33%, 26.67%, 18.89%, 6.67%, 3.33%),
  align: (left,left,left,left,left,left,),
  table.header([], [Sums of squares (SS)], [Degrees of freedom (df)], [Mean square (MS)], [F], [p],),
  table.hline(),
  [Group (our effect)], [42], [2], [21], [15.75], [],
  [Error/Residual], [12], [9], [1.33], [], [],
  [Total], [54], [], [], [], [],
)
If we were to calculate an eta-squared value for this, we would use SS effect (42) and SSt (54) like so:

$ eta^2 = 42 / 54 = .778 $

=== Interpreting eta-squared
<interpreting-eta-squared>
Cohen (1988) provided the following guidelines for interpreting eta-squared:

- $eta^2$ = .01 is a small effect
- $eta^2$ = .06 is a medium effect
- $eta^2$ = .14 is a large effect

With these guidelines (which aren't perfect), a $eta^2$ of .778 is astronomically huge.

Alternatively, when it comes to eta-squared you can avoid using benchmarks entirely and interpret them as the amount of variance (as a percentage) explained in the DV by the IV, as described above.

== One-way ANOVA
<one-way-anova>
#block(fill: rgb("#f5f5f5"))[
In the previous section, we looked at how to compare differences between either two groups, or two points in time. But how do we compare more than that? The answer is the ANOVA (analysis of variance) - one of the most common general statistical models for hypothesis testing. If you do some statistical testing as part of your thesis, the ANOVA is likely going to be one of your most useful tools to have.

]
=== The basic one-way ANOVA
<the-basic-one-way-anova>
The between-groups one-way ANOVA is the most basic form of ANOVA, which aims to test differences between two or more groups. (Typically, ANOVAs are used when there are three or more groups, but can easily be used in situations where there are only two groups.)

We've briefly mentioned the general hypotheses for all ANOVAs, but here they are again:

- $H_0$: The means between groups are not significantly different. (i.e.~$mu_1 = mu_2 = . . . mu_k$)
- $H_1$: The means between groups are significantly different. (i.e.$mu_1 eq.not mu_2 eq.not . . . mu_k$)

=== Example data
<example-data-3>
In the seminar, we talk about an example from Watts et al.~(2003). Below is another simple example, comparing taste ratings across three different types of slices: caramel slices, vanilla slices and lemon slices. Participants were randomly allocated to taste one of the three slices blindfolded, and were then asked to verbally rate its taste on a scale from 1-10 (10 being super tasty).

#block[
#Skylighting(([#NormalTok("w9_slices ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_9\"");#NormalTok(", ");#StringTok("\"w9_slices.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 63 Columns: 2");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (1): group");],
[#NormalTok("dbl (1): rating");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
#Skylighting(([#CommentTok("# Create factor");],
[#NormalTok("w9_slices");#SpecialCharTok("$");#NormalTok("group ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(w9_slices");#SpecialCharTok("$");#NormalTok("group)");],
[],
[#FunctionTok("head");#NormalTok("(w9_slices)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 2");],
[#NormalTok("  group   rating");],
[#NormalTok("  <fct>    <dbl>");],
[#NormalTok("1 caramel      6");],
[#NormalTok("2 vanilla      8");],
[#NormalTok("3 lemon        4");],
[#NormalTok("4 caramel      6");],
[#NormalTok("5 vanilla      6");],
[#NormalTok("6 lemon        7");],));
]
]
=== Assumption checks
<assumption-checks-3>
In R, to test assumptions we need to run the ANOVA #emph[first]. This is because some assumptions rely on values that are calculated when the ANOVA is run. Other programs, such as Jamovi and SPSS, will hide this manual work and present the information to you automatically. This is not quite the case in R, but that's ok!

The basic function for running an ANOVA in R is the #NormalTok("aov()"); function, which takes a formula input (much like #NormalTok("t.test()");). Anything created using #NormalTok("aov()"); should be assigned to a new variable so that we can use it later. This creates an #NormalTok("aov"); object that will a) test our main effects and b) let us check some of our assumptions.

#block[
#Skylighting(([#NormalTok("w9_slices_aov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov");#NormalTok("(rating ");#SpecialCharTok("~");#NormalTok(" group, ");#AttributeTok("data =");#NormalTok(" w9_slices)");],));
]
There are four main assumptions for a basic ANOVA.

- Data must be independent of each other - in other words, one person's response should not be influenced by another. This should come as a feature of good experimental design.
- The residuals should be normally distributed. We can assess this using the same methods as #emph[t]-tests: either a QQ plot or a normality test (e.g.~Shapiro-Wilks). You can access the residuals from the #NormalTok("aov"); object directly like this:

#block[
#Skylighting(([#NormalTok("w9_slices_aov");#SpecialCharTok("$");#NormalTok("residuals");],));
]
This lets us do the SW test:

#block[
#Skylighting(([#FunctionTok("shapiro.test");#NormalTok("(w9_slices_aov");#SpecialCharTok("$");#NormalTok("residuals)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  w9_slices_aov$residuals");],
[#NormalTok("W = 0.95117, p-value = 0.01409");],));
]
]
A SW test on this data suggests the assumption is violated (#emph[W] =.951, #emph[p] = .014), suggesting that the residuals are not normally distributed.

This is a bit of a problem in our dataset because our sample is relatively small. However - the ANOVA is fairly robust to violations of the normality assumption, meaning that non-normal residuals aren't a major problem so long as a) you have a big enough sample size and b) the skew isn't huge (or driven by outliers).

- The equality of variance (homoscedasticity) assumption.

This means that the variances within each group are the same. We test this using Levene's test, using the #NormalTok("levene_test()"); function. Helpfully, #NormalTok("levene_test()"); is flexible enough to work with either a formula #emph[or] an #NormalTok("aov"); object we have already fitted:

#block[
#Skylighting(([#CommentTok("# Either one of these will work");],
[#NormalTok("w9_slices ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("levene_test");#NormalTok("(rating ");#SpecialCharTok("~");#NormalTok(" group, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],
[],
[#FunctionTok("levene_test");#NormalTok("(w9_slices_aov, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],));
]
#block[
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 4");],
[#NormalTok("    df1   df2 statistic     p");],
[#NormalTok("  <int> <int>     <dbl> <dbl>");],
[#NormalTok("1     2    60     0.721 0.491");],));
]
]
The assumption doesn't appear to be violated (#emph[F]\(2, 60) = .721, #emph[p] = .491). If it was, we might consider using a Welch's ANOVA, which can be done with #NormalTok("welch_anova_test()"); from #NormalTok("rstatix");.

For now though, we'll press ahead.

=== Output
<output-5>
Here's our main output from the ANOVA, generated using the #NormalTok("summary()"); function. This is called an omnibus, because it is a general test of the hypotheses:

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(w9_slices_aov)");],));
#block[
#Skylighting(([#NormalTok("            Df Sum Sq Mean Sq F value  Pr(>F)   ");],
[#NormalTok("group        2  22.22  11.111   6.897 0.00201 **");],
[#NormalTok("Residuals   60  96.67   1.611                   ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
]
Our main results suggest that there is a significant difference between means (#emph[F]\(2, 60) = 6.90, #emph[p] = .002).

=== Post-hoc tests
<post-hoc-tests-1>
The output above told us that we could reject our basic null hypothesis - that there was no difference between means. However, remember that it doesn't tell us where those differences are. To figure out where they are, we need to follow up that ANOVA with post-hoc tests.

To generate post-hocs, there are a couple of ways. Tukey tests can be calculated with #NormalTok("TukeyHSD()"); or #NormalTok("emmeans()");:

#block[
#Skylighting(([#FunctionTok("TukeyHSD");#NormalTok("(w9_slices_aov)");],));
#block[
#Skylighting(([#NormalTok("  Tukey multiple comparisons of means");],
[#NormalTok("    95% family-wise confidence level");],
[],
[#NormalTok("Fit: aov(formula = rating ~ group, data = w9_slices)");],
[],
[#NormalTok("$group");],
[#NormalTok("                      diff        lwr       upr     p adj");],
[#NormalTok("lemon-caramel   -0.4761905 -1.4175618 0.4651809 0.4486738");],
[#NormalTok("vanilla-caramel  0.9523810  0.0110096 1.8937523 0.0467882");],
[#NormalTok("vanilla-lemon    1.4285714  0.4872001 2.3699428 0.0015928");],));
]
]
#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(w9_slices_aov, ");#SpecialCharTok("~");#NormalTok(" group) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#StringTok("\"tukey\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok(" contrast          estimate    SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" caramel - lemon      0.476 0.392 60   -0.465    1.418   1.216  0.4487");],
[#NormalTok(" caramel - vanilla   -0.952 0.392 60   -1.894   -0.011  -2.431  0.0468");],
[#NormalTok(" lemon - vanilla     -1.429 0.392 60   -2.370   -0.487  -3.647  0.0016");],
[],
[#NormalTok("Confidence level used: 0.95 ");],
[#NormalTok("Conf-level adjustment: tukey method for comparing a family of 3 estimates ");],
[#NormalTok("P value adjustment: tukey method for comparing a family of 3 estimates ");],));
]
]
Here, you can see that we run a test for caramel vs lemon, caramel vs vanilla and lemon vs vanilla. For post-hocs in one-way ANOVAs, it is ok to stick to the Tukey-adjusted #emph[p]-values. We can see that:

- There is no significant difference between ratings of caramel and lemon slices (mean difference, MD = .48; #emph[p] = .449).
- There is a (marginal) significant difference between caramel and vanilla slices; participants rated vanilla slices higher than caramel slices (MD = .95, #emph[p] = .047).
- There is a significant difference between lemon and vanilla slices, in that participants preferred vanilla slices (MD = 1.43, #emph[p] = .002).

To generate Bonferroni or Holm-corrected #emph[p]-values, you need to use the #NormalTok("pairwise.t.test()"); function:

#block[
#Skylighting(([#FunctionTok("pairwise.t.test");#NormalTok("(");#AttributeTok("x =");#NormalTok(" w9_slices");#SpecialCharTok("$");#NormalTok("rating, ");#AttributeTok("g =");#NormalTok(" w9_slices");#SpecialCharTok("$");#NormalTok("group, ");#AttributeTok("p.adjust.method =");#NormalTok(" ");#StringTok("\"holm\"");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    Pairwise comparisons using t tests with pooled SD ");],
[],
[#NormalTok("data:  w9_slices$rating and w9_slices$group ");],
[],
[#NormalTok("        caramel lemon ");],
[#NormalTok("lemon   0.2289  -     ");],
[#NormalTok("vanilla 0.0361  0.0017");],
[],
[#NormalTok("P value adjustment method: holm ");],));
]
]
In this case, you must provide #NormalTok("p.adjust.method"); as an argument. By default, this function will use Holm corrections. Alternatively, just change your #NormalTok("emmeans()"); call:

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(w9_slices_aov, ");#SpecialCharTok("~");#NormalTok(" group) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#StringTok("\"holm\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok(" contrast          estimate    SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" caramel - lemon      0.476 0.392 60   -0.489   1.4410   1.216  0.2289");],
[#NormalTok(" caramel - vanilla   -0.952 0.392 60   -1.917   0.0124  -2.431  0.0361");],
[#NormalTok(" lemon - vanilla     -1.429 0.392 60   -2.393  -0.4638  -3.647  0.0017");],
[],
[#NormalTok("Confidence level used: 0.95 ");],
[#NormalTok("Conf-level adjustment: bonferroni method for 3 estimates ");],
[#NormalTok("P value adjustment: holm method for 3 tests ");],));
]
]
Here is how a write-up might look:

#block(fill: rgb("#cce3c8"))[
A one-way ANOVA was conducted to examine whether there were differences in preferences for types of slices. There was a significant large main effect of slice type (#emph[F]\(2, 60) = 6.90, #emph[p] = .002, $eta^2$ = .187). Post-hoc tests with Tukey HSD corrections showed that participants rated vanilla slices higher than caramel slices (mean difference, #emph[MD] = .95, #emph[p] = .047), as well as significantly higher than lemon slices (#emph[MD] = 1.43, #emph[p] = .002). However, there was no significant differencce between caramel and lemon slices (#emph[p] = .449).

]
== One-way repeated measures ANOVA
<one-way-repeated-measures-anova>
#block(fill: rgb("#f5f5f5"))[
The second form of ANOVA that we will cover in this module is the repeated measures ANOVA (sometimes abbreviated as RM-ANOVA). While it shares many features with the basic one-way ANOVA, the nature of repeated measures data introduces some key differences in the interpretation and calculation of this test.

]
=== Repeated measures ANOVAs
<repeated-measures-anovas>
In principle, a repeated-measures ANOVA is very similar to the paired-samples #emph[t]-test: both are repeated measures versions of their respective between-groups versions. So naturally, repeated-measures ANOVAs are used when we test one sample two or more times (again, like a regular ANOVA, it's typically for 3+ times but can be used for two).

It shares many similarities with the basic one-way ANOVA, albeit with one additional step in calculation: because we now test the same sample repeatedly, we need to account for variance within subjects. We won't go too into detail about how that's calculated here, but essentially we split within-groups variance into subject variance and error/residual variance. This essentially adds an extra step to the ANOVA table.

=== Example data
<example-data-4>
In this example, we'll use a dataset derived from #link("https://journals.sagepub.com/doi/abs/10.1177/0305735605048012")[McPherson (2005)]. This is a subset of data where children were scored on their ability to play songs from memory over three years - 1997 - 1999. We're interested in seeing whether this change over time is significant - therefore, time (3 levels) is our independent variable, while playing from memory is our dependent variable.

#block[
#Skylighting(([#NormalTok("w9_memory ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"Week_9\"");#NormalTok(", ");#StringTok("\"w9_playing_from_memory.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 95 Columns: 4");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("dbl (4): Participant, PFM_97, PFM_98, PFM_99");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
#Skylighting(([#FunctionTok("head");#NormalTok("(w9_memory)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 4");],
[#NormalTok("  Participant PFM_97 PFM_98 PFM_99");],
[#NormalTok("        <dbl>  <dbl>  <dbl>  <dbl>");],
[#NormalTok("1           1     56    131    139");],
[#NormalTok("2           2     84    114    138");],
[#NormalTok("3           3    159    173    199");],
[#NormalTok("4           4    110    147    160");],
[#NormalTok("5           5    118    148    158");],
[#NormalTok("6           6    131    155    177");],));
]
]
For further analyses, we'll shape this into long format:

#block[
#Skylighting(([#NormalTok("w9_memory_wide ");#OtherTok("<-");#NormalTok(" w9_memory");],
[],
[#NormalTok("w9_memory ");#OtherTok("<-");#NormalTok(" w9_memory ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pivot_longer");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("cols =");#NormalTok(" PFM_97");#SpecialCharTok(":");#NormalTok("PFM_99,");],
[#NormalTok("    ");#AttributeTok("names_to =");#NormalTok(" ");#StringTok("\"time\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("values_to =");#NormalTok(" ");#StringTok("\"memory_score\"");],
[#NormalTok("  )");],));
]
=== Assumption checks
<assumption-checks-4>
There are two main assumptions for a repeated-measures ANOVA. Note that while the independence assumption as we know it doesn't apply here (by definition, repeated data is dependent), good experimental design should still aim to ensure that participants are independent of each other.

- The residuals should be normally distributed.

Our usual tests apply here too. Below is a QQ plot, which might suggest that our residuals aren't normally distributed. (Use the data and perform a SW test on it to see what happens!)

#Skylighting(([#FunctionTok("aov");#NormalTok("(memory_score ");#SpecialCharTok("~");#NormalTok(" time, ");#AttributeTok("data =");#NormalTok(" w9_memory) ");#SpecialCharTok("%>%");],
[#NormalTok("  broom");#SpecialCharTok("::");#FunctionTok("augment");#NormalTok("() ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("sample =");#NormalTok(" .std.resid)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_qq");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_qq_line");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("Warning: The `augment()` method for objects of class `aov` is not maintained by the broom team, and is only supported through the `lm` tidier method. Please be cautious in interpreting and reporting broom output.");],
[],
[#NormalTok("This warning is displayed once per session.");],));
]
#box(image("06-anovas_files/figure-typst/unnamed-chunk-34-1.svg"))

- The sphericity assumption. Sphericity is assumed if, the variances of the differences between each level of the IV are equal. Think of it as a form of the equality of variances assumption, where we assumed that the variances within groups were equal. The sphericity assumption applies to the differences between T1 and T2, then T2 and T3… etc etc.

Note that sphericity only applies when you have at least 3 levels of your IV (i.e.~3 timepoints). We can formally test it using Mauchly's test of sphericity. If sphericity is violated, it means that our degrees of freedom are too high for the data, which inflates the Type I error rate.

What next? We need to apply a correction to the omnibus ANOVA, which will alter the #emph[p]-value. There are two on offer: Greenhouse-Geisser and Huynh-Feldt corrections. To help decide which one to use, R also calculates a value called epsilon ($epsilon.alt$). Epsilon, in short, is a measure of sphericity; if sphericity is assumed, $epsilon.alt$ = 1. If $epsilon.alt$ is below 1, sphericity is violated; the smaller it is, the greater the violation and therefore the greater the correction needs to be. Therefore, these corrections alter the degrees of freedom for each test to account for this higher error rate.

\(Mathematical note; the corrected dfs are calculated by multiplying the original dfs by $epsilon.alt$. So e.g.~if your original df is 10 and $epsilon.alt$ = 0.9, your new corrected df will be 9.)

Broadly:

- If epsilon ($epsilon.alt$) \> .75, use the Huynh-Feldt correction.
- If epsilon ($epsilon.alt$) \< .75, use the Greenhouse-Geisser correction.

In R, most main packages will test the sphericity assumption along with the main ANOVA, so we will see this below.

=== ANOVA output
<anova-output>
Repeated measures ANOVAs in R are surprisingly #emph[not] trivial to conduct, to the point where even adapting the Jamovi version of this analysis was a genuine challenge. To some extent this probably reflects the differences in approach between point-and-click software compared to actually having to code the ANOVA model: the former is easy but you perhaps make certain assumptions about what's going on along the way.

For that reason, now is a good time to introduce the #NormalTok("afex"); package, which stands for "analysis of factorial experiments". The #NormalTok("aov_ez()"); function will let us specify a repeated measures ANOVA in a very easy way. See below for an alternative using #NormalTok("rstatix");, although this is less flexible than the #NormalTok("afex"); version.

At a minimum, you must give the following arguments to #NormalTok("aov_ez()");:

- #NormalTok("id");: The name of the column that identifies each participant
- #NormalTok("dv");: The dependent variable/outcome
- #NormalTok("data");: The name of the dataset
- #NormalTok("within");: The name of the within-subjects IV/predictor

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(afex)");],));
#block[
#Skylighting(([#NormalTok("Loading required package: lme4");],));
]
#block[
#Skylighting(([#NormalTok("Loading required package: Matrix");],));
]
#block[
#Skylighting(([],
[#NormalTok("Attaching package: 'Matrix'");],));
]
#block[
#Skylighting(([#NormalTok("The following objects are masked from 'package:tidyr':");],
[],
[#NormalTok("    expand, pack, unpack");],));
]
#block[
#Skylighting(([#NormalTok("Registered S3 method overwritten by 'lme4':");],
[#NormalTok("  method           from");],
[#NormalTok("  na.action.merMod car ");],));
]
#block[
#Skylighting(([#NormalTok("************");],
[#NormalTok("Welcome to afex. For support visit: http://afex.singmann.science/");],));
]
#block[
#Skylighting(([#NormalTok("- Functions for ANOVAs: aov_car(), aov_ez(), and aov_4()");],
[#NormalTok("- Methods for calculating p-values with mixed(): 'S', 'KR', 'LRT', and 'PB'");],
[#NormalTok("- 'afex_aov' and 'mixed' objects can be passed to emmeans() for follow-up tests");],
[#NormalTok("- Get and set global package options with: afex_options()");],
[#NormalTok("- Set sum-to-zero contrasts globally: set_sum_contrasts()");],
[#NormalTok("- For example analyses see: browseVignettes(\"afex\")");],
[#NormalTok("************");],));
]
#block[
#Skylighting(([],
[#NormalTok("Attaching package: 'afex'");],));
]
#block[
#Skylighting(([#NormalTok("The following object is masked from 'package:lme4':");],
[],
[#NormalTok("    lmer");],));
]
#Skylighting(([#NormalTok("w9_memory_aov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov_ez");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("id =");#NormalTok(" ");#StringTok("\"Participant\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("dv =");#NormalTok(" ");#StringTok("\"memory_score\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("data =");#NormalTok(" w9_memory,");],
[#NormalTok("  ");#AttributeTok("within =");#NormalTok(" ");#StringTok("\"time\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("type =");#NormalTok(" ");#DecValTok("3");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("anova_table =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("correction =");#NormalTok(" ");#StringTok("\"HF\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("es =");#NormalTok(" ");#StringTok("\"pes\"");],
[#NormalTok("  )");],
[#NormalTok(")");],));
]
Also worth noting is the #NormalTok("anova_table"); argument, which specifies options for the main output. This argument takes a #NormalTok("list()"); as the argument, and we can set multiple options within this list. Here, we have set two:

- #NormalTok("correction = \"HF\""); specifies Huynh-Felt corrections. We can also ask for Greenhouse-Geisser corrections using #NormalTok("correction = \"GG\"");.
- #NormalTok("es = \"pes\""); specifies partial eta-squared for effect size. This is ok for a one-way ANOVA; recall that for a one-way setting, normal and partial eta-squared are the same.

Now that we've built our ANOVA model we can ask for the output like so. This will also print out the sphericity test.

Here's our overall output from the ANOVA. It looks (and reads) pretty much the same as our previous example, albeit with some minor differences.

To see the full output, including the sphericity test, call #NormalTok("summary()"); on your ANOVA object:

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(w9_memory_aov)");],));
#block[
#Skylighting(([],
[#NormalTok("Univariate Type III Repeated-Measures ANOVA Assuming Sphericity");],
[],
[#NormalTok("             Sum Sq num Df Error SS den Df F value    Pr(>F)    ");],
[#NormalTok("(Intercept) 3490869      1   259027     94 1266.83 < 2.2e-16 ***");],
[#NormalTok("time          98948      2    70130    188  132.63 < 2.2e-16 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[],
[#NormalTok("Mauchly Tests for Sphericity");],
[],
[#NormalTok("     Test statistic  p-value");],
[#NormalTok("time        0.93912 0.053894");],
[],
[],
[#NormalTok("Greenhouse-Geisser and Huynh-Feldt Corrections");],
[#NormalTok(" for Departure from Sphericity");],
[],
[#NormalTok("      GG eps Pr(>F[GG])    ");],
[#NormalTok("time 0.94261  < 2.2e-16 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("        HF eps   Pr(>F[HF])");],
[#NormalTok("time 0.9612827 2.447568e-35");],));
]
]
Here, our #emph[p]-value for Mauchly's test is almost significant (#emph[p] = .054); rather than going by a strict arbitrary cutoff, let's assume that it has been violated (both for teaching and for methodological purposes). Here, our epsilon value is high (\~.95), so let's apply the Hyunh-Feldt correction. The associated epsilon value is $epsilon.alt = .943$\; when reporting the repeated measures ANOVA we need to look at the rows corresponding to the Huynh-Feldt correction.

#NormalTok("afex"); will print out the #emph[corrected] version of the test if you just print the object without using #NormalTok("summary()");.

#block[
#Skylighting(([#NormalTok("w9_memory_aov");],));
#block[
#Skylighting(([#NormalTok("Anova Table (Type 3 tests)");],
[],
[#NormalTok("Response: memory_score");],
[#NormalTok("  Effect           df    MSE          F  pes p.value");],
[#NormalTok("1   time 1.92, 180.72 388.06 132.63 *** .585   <.001");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '+' 0.1 ' ' 1");],
[],
[#NormalTok("Sphericity correction method: HF ");],));
]
]
Thus, with the corrected output we can see our effect of time is significant (#emph[F]\(1.92, 180.72) = 132.63, #emph[p] \< .001).

A benefit of doing a repeated-measures ANOVA this way is that this model is compatible with the #NormalTok("effectsize"); functions, including #NormalTok("eta_squared()");:

#block[
#Skylighting(([#FunctionTok("eta_squared");#NormalTok("(w9_memory_aov, ");#AttributeTok("alternative =");#NormalTok(" ");#StringTok("\"two.sided\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# Effect Size for ANOVA (Type III)");],
[],
[#NormalTok("Parameter | Eta2 (partial) |       95% CI");],
[#NormalTok("-----------------------------------------");],
[#NormalTok("time      |           0.59 | [0.50, 0.65]");],));
]
]
=== Post-hoc tests
<post-hoc-tests-2>
As per usual, we follow up a significant overall ANOVA with a series of post-hoc comparisons:

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(w9_memory_aov, ");#SpecialCharTok("~");#NormalTok(" time) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#StringTok("\"holm\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok(" contrast        estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" PFM_97 - PFM_98    -29.6 2.82 94    -36.5   -22.74 -10.501 <0.0001");],
[#NormalTok(" PFM_97 - PFM_99    -44.9 3.08 94    -52.4   -37.38 -14.577 <0.0001");],
[#NormalTok(" PFM_98 - PFM_99    -15.3 2.48 94    -21.3    -9.24  -6.170 <0.0001");],
[],
[#NormalTok("Confidence level used: 0.95 ");],
[#NormalTok("Conf-level adjustment: bonferroni method for 3 estimates ");],
[#NormalTok("P value adjustment: holm method for 3 tests ");],));
]
]
As an alternative, we can use #NormalTok("pairwise.t.test()");. Note this time we set #NormalTok("paired = TRUE");.

#block[
#Skylighting(([#FunctionTok("pairwise.t.test");#NormalTok("(w9_memory");#SpecialCharTok("$");#NormalTok("memory_score, w9_memory");#SpecialCharTok("$");#NormalTok("time, ");#AttributeTok("paired =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    Pairwise comparisons using paired t tests ");],
[],
[#NormalTok("data:  w9_memory$memory_score and w9_memory$time ");],
[],
[#NormalTok("       PFM_97  PFM_98 ");],
[#NormalTok("PFM_98 < 2e-16 -      ");],
[#NormalTok("PFM_99 < 2e-16 1.7e-08");],
[],
[#NormalTok("P value adjustment method: holm ");],));
]
]
From this, we can see that all three means are significantly different from each other (#emph[p] \< .001, for brevity's sake). Scores increased year on year, i.e.~1997 \< 1998 \< 1999.

#block(fill: rgb("#cce3c8"))[
A one-way repeated measures ANOVA was conducted to examine whether scores for playing songs from memory changed over three years. We applied Huynh-Feldt corrections to account for non-sphericity. There was a significant large effect of year on performance scores (#emph[F]\(1.92, 180.72) = 132.63, #emph[p] \< .001, $eta^2$ = .231). Post-hoc tests with Tukey HSD corrections showed that participants scored higher in 1998 than in 1997 (mean difference, #emph[MD] = 29.61, #emph[p] \< .001). Participants also scored higher in 1999 compared to 1998 (#emph[MD] = 15.27, #emph[p] \< .001) and 1997 (#emph[MD] = 44.88, #emph[p] \< .001).

]
=== Alternative using #NormalTok("rstatix");
<alternative-using-rstatix>
As mentioned above, repeated measures ANOVAs in R are not trivial at all. The solution using #NormalTok("rstatix"); above is good, although it is not fully ideal.

Below is an alternative way of running a repeated measures ANOVA, this time using the #NormalTok("rstatix"); package. It even uses similar arguments to the #NormalTok("afex"); version above.

#block[
#Skylighting(([#NormalTok("w9_memory_aov2 ");#OtherTok("<-");#NormalTok(" w9_memory ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("anova_test");#NormalTok("(");#AttributeTok("dv =");#NormalTok(" memory_score, ");#AttributeTok("wid =");#NormalTok(" Participant, ");#AttributeTok("within =");#NormalTok(" time) ");],));
]
#block[
#Skylighting(([#NormalTok("w9_memory_aov2");],));
#block[
#Skylighting(([#NormalTok("ANOVA Table (type III tests)");],
[],
[#NormalTok("$ANOVA");],
[#NormalTok("  Effect DFn DFd       F        p p<.05   ges");],
[#NormalTok("1   time   2 188 132.625 1.19e-36     * 0.231");],
[],
[#NormalTok("$`Mauchly's Test for Sphericity`");],
[#NormalTok("  Effect     W     p p<.05");],
[#NormalTok("1   time 0.939 0.054      ");],
[],
[#NormalTok("$`Sphericity Corrections`");],
[#NormalTok("  Effect   GGe       DF[GG]    p[GG] p[GG]<.05   HFe       DF[HF]    p[HF]");],
[#NormalTok("1   time 0.943 1.89, 177.21 1.05e-34         * 0.961 1.92, 180.72 2.45e-35");],
[#NormalTok("  p[HF]<.05");],
[#NormalTok("1         *");],));
]
]
The two columns to look for are the ones labelled #NormalTok("DF[HF]"); - this gives the adjusted degrees of freedom with the Huynh-Feldt corrections (#NormalTok("DF[GG]"); would give Greenhouse-Geisser dfs) - and #NormalTok("p[HF]");, which gives the adjusted #emph[p]-value.

Note that the #NormalTok("rstatix"); version is not compatible with either #NormalTok("eta_squared()"); (from the #NormalTok("effectsize"); package) or #NormalTok("emmeans");. If you want post-hocs, you will need to use the #NormalTok("pairwise.t.test()"); function or its #NormalTok("rstatix"); equivalent. However, this does mean that it is not possible to do Tukey adjustments.

#block[
#Skylighting(([#NormalTok("w9_memory ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairwise_t_test");#NormalTok("(memory_score ");#SpecialCharTok("~");#NormalTok(" time, ");#AttributeTok("paired =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("p.adjust.method =");#NormalTok(" ");#StringTok("\"holm\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 3 × 10");],
[#NormalTok("  .y.   group1 group2    n1    n2 statistic    df        p    p.adj p.adj.signif");],
[#NormalTok("* <chr> <chr>  <chr>  <int> <int>     <dbl> <dbl>    <dbl>    <dbl> <chr>       ");],
[#NormalTok("1 memo… PFM_97 PFM_98    95    95    -10.5     94 1.59e-17 3.18e-17 ****        ");],
[#NormalTok("2 memo… PFM_97 PFM_99    95    95    -14.6     94 7.35e-26 2.21e-25 ****        ");],
[#NormalTok("3 memo… PFM_98 PFM_99    95    95     -6.17    94 1.71e- 8 1.71e- 8 ****        ");],));
]
]
= Linear relationships
<linear-relationships>
Up until now we've been dealing almost exclusively with categorical variables in some way. For example, chi-square tests are for testing relationships between categorical variables; likewise, t-tests and ANOVAs deal with categorical IVs against continuous DVs. In reality though, many of the things we're interested in are inherently continuous in nature. There are very few psychological constructs that aren't continuous in some way, and so working with continuous variables forms a core part of doing statistical analyses.

Enter the linear regression and its many other forms - in some ways, the bedrock of many of the research that we do (more on this in Week 11). When we're dealing with continuous variables, linear regressions are generally the first place to start. We won't go much further beyond the basics here (certainly as it applies to a lot of psychological research), but even these concepts are foundational for many reasons.

By the end of this module you should be able to:

- Describe how hypothesis testing works in regressions - including what is being tested
- Conduct appropriate assumption tests for a linear regression
- Run a linear regression and interpret the output
- Make predictions based on the output of a linear regression
- Run and interpret a multiple regression

#figure([
#box(image("index_files\\mediabag\\linear_regression.png"))
], caption: figure.caption(
position: bottom, 
[
#link("https://xkcd.com/1725/")[xkcd: Linear Regression]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


== Correlations
<correlations>
#block(fill: rgb("#f5f5f5"))[
We've talked a surprising amount about correlations in this subject, but we haven't considered how to actually test if two things are correlated to begin with. We change that this week with an overview of correlation coefficients.

]
=== Covariance
<covariance>
To start, examine the figure below. The figure below plots the gestational period lengths of \~1230 pregnancies, plotted against the birth weight of the child.

#align(center)[#box(image("07-regressions_files/figure-typst/unnamed-chunk-3-1.svg"))]
A trend might be immediately obvious - longer gestational periods are associated with higher birth weights. We can say that the two variables - gestation length and birth weight - #strong[covary] with each other, as a change in one variable is associated with change in another.

#strong[Covariance] simply describes and quantifies how two variables change with each other. For instance, if two variables have a positive covariance, this means that as one variable increases, so does the other. Similarly, if two variables have a negative covariance, this means that as one increases the other decreases.

How is covariance calculated?
The formula for the covariance between two variables X and Y is given as:

$ q = frac(Sigma \( x_i - macron(x) \) \( y_i - macron(y) \), N - 1) $

Where $x_i$ and $y_i$ refer to the individual values for variables X and Y respectively, and $macron(x)$ and $macron(y)$ refer to the means of variables X and Y respectively. Put simply:

- Subtract each participant's value for variable X from the mean of variable X.
- Do the same for each participant on variable Y - their individual value minus the mean of Y.
- For each participant, multiply the two differences together.
- Sum this value across all participants.
- Divide by N - 1.

=== Correlation coefficients
<correlation-coefficients>
We can quantify the strength of two variables using a #strong[correlation coefficient], which gives us a measure of how tightly these two variables are related. There are many types of correlation coefficients, but the most common is the #strong[Pearson's correlation coefficient, r]. It's calculated using the below (simplified) formula:

$ r = frac(C o v_(x y), S D_x times S D_y) $

In this subject we won't expect you to calculate a correlation coefficient by hand, but the key takeaway here is that by dividing a value by a standard deviation (or, in this case, a product of two SDs), we are #strong[standardising] the covariance. Hence, a correlation coefficient is a #strong[standardised] measure, meaning that we can compare correlation coefficients quite easily across variables regardless of their scale.

Correlation coefficients have the following properties:

- They are between -1 and +1
- The sign of the correlation describes the direction - a positive value represents a positive correlation
- The numerical value describes the magnitude
- A correlation of 1 means a perfect correlation; a correlation of 0 means a negative correlation
- A rough guideline for this subject, r = .20 is weak, r = .50 is moderate, r = .70 is strong
- Visually, a magnitude of 0 corresponds to a flat line; the steeper the line, the higher the magnitude

=== Activity
<activity>
See if you can describe what the covariances would be like below:

#box(image("img/w10_cor_examples.svg"))

Look at the below correlation coefficients.

#table(
  columns: 3,
  align: (right,left,left,),
  table.header([], [Is it positive or negative?], [How strong is it?],),
  table.hline(),
  [0.35], [], [],
  [-0.24], [], [],
  [-0.02], [], [],
  [0.85], [], [],
)
=== Testing correlations in R
<testing-correlations-in-r>
Statistical programs like Jamovi and R will allow us to not only quantify a correlation between two variables, but test whether this correlation is significant. Generally, when working with continuous data it never hurts to run a basic correlation.

Here is an example using a simple dataset containing the gender, height and speed (the fastest they had ever driven).

#block[
#Skylighting(([#NormalTok("w10_speed ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_10\"");#NormalTok(", ");#StringTok("\"W10_speed.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("New names:");],
[#NormalTok("Rows: 1325 Columns: 4");],
[#NormalTok("── Column specification");],
[#NormalTok("──────────────────────────────────────────────────────── Delimiter: \",\" chr");],
[#NormalTok("(1): gender dbl (3): ...1, speed, height");],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data. ℹ");],
[#NormalTok("Specify the column types or set `show_col_types = FALSE` to quiet this message.");],
[#NormalTok("• `` -> `...1`");],));
]
]
Let's correlate height and speed. This can easily be done in R by using the #NormalTok("cor.test()"); function. You simply need to give it the names of the two columns you want to correlate. By default, this function will run a Pearson's correlation.

#block[
#Skylighting(([#FunctionTok("cor.test");#NormalTok("(w10_speed");#SpecialCharTok("$");#NormalTok("height, w10_speed");#SpecialCharTok("$");#NormalTok("speed)");],));
#block[
#Skylighting(([],
[#NormalTok("    Pearson's product-moment correlation");],
[],
[#NormalTok("data:  w10_speed$height and w10_speed$speed");],
[#NormalTok("t = 9.2871, df = 1300, p-value < 2.2e-16");],
[#NormalTok("alternative hypothesis: true correlation is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" 0.1977889 0.2997013");],
[#NormalTok("sample estimates:");],
[#NormalTok("      cor ");],
[#NormalTok("0.2494356 ");],));
]
]
We can see that our correlation is #emph[r] = .249, which is a relatively weak to moderate correlation. This correlation is also significant (#emph[p] \< .001). We also get a confidence interval around the size of the correlation, which is great for showing the range of possible values. So we might write this up as something like:

#block(fill: rgb("#cce3c8"))[
There was a significant weak positive correlation between students' heights and their fastest ever driving speed (#emph[r]\(1300) = .25, #emph[p] \< .001; 95% CI \[.20, .30\]).

]
=== Displaying correlations
<displaying-correlations>
It is common to compute correlation coefficients between multiple variables at the same time and display them. In more complex analyses, this is often a crucial early step in the analytical process. Below are two ways of visualising multiple correlations, using fictional questionnaire data.

The first is simply a #strong[correlation matrix], like below:

#table(
  columns: 5,
  align: (left,right,right,right,right,),
  table.header([], [Q1], [Q2], [Q3], [Q4],),
  table.hline(),
  [Q1], [1.00], [0.24], [-0.56], [0.72],
  [Q2], [0.24], [1.00], [-0.38], [0.43],
  [Q3], [-0.56], [-0.38], [1.00], [-0.11],
  [Q4], [0.72], [0.43], [-0.11], [1.00],
)
The second is a #strong[correlation heatmap], which is especially effective with many correlations at once (common when working with huge questionnaires or neuroimaging). As shown by the legend on the right, the colour and shade of each square are determined by the strength of the correlation. This can be easily done by the \`#NormalTok("ggcorrplot"); package, if you have a correlation matrix formatted in R:

#Skylighting(([#FunctionTok("library");#NormalTok("(ggcorrplot)");],
[#FunctionTok("ggcorrplot");#NormalTok("(cor_mat, ");#AttributeTok("type =");#NormalTok(" ");#StringTok("\"lower\"");#NormalTok(", ");#AttributeTok("show.diag =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#box(image("07-regressions_files/figure-typst/unnamed-chunk-9-1.svg"))

== Regression hypotheses
<regression-hypotheses>
#block(fill: rgb("#f5f5f5"))[
Let's move on from correlations to regressions, where we test whether one variable can predict another. To do that, let's start by considering what a linear regression actually is, and how it works.

]
=== What is regression?
<what-is-regression>
Recall the gestation versus birth weight example from the previous page:

#align(center)[#box(image("07-regressions_files/figure-typst/unnamed-chunk-10-1.svg"))]
On the previous page, we saw that these two variables covary - as gestation length increases, the birth weight of the infant increases as well. We might then be interested in seeing whether gestational length #emph[predicts] birth weight. In other words, does the gestational period of a pregnancy significantly predict the weight of the baby?

#strong[Regression] is a technique that allows us to see whether one or more independent variables predict a (continuous) dependent variable. Regression is one of the most widely used techniques in psychology because we are often interested in relationships between continuous variables, #emph[and] we are often interested in seeing whether certain variables predict others. Put simply, it allows us to examine relationships between variables (like correlations), but is a very flexible and powerful method of doing so.

Let's kick off the regression portion of this module with a bit of terminology:

- The line is called the line of best fit. The slope of the line is, well, the slope. It describes how much Y changes if X changes by one unit.
- The point at which the line crosses the y-axis is called the intercept (the y-intercept in full). The intercept is one of the two paramaters of a regression line (the other being the slope).

In this module, we will also call the independent variable a #strong[predictor], and the dependent variable the #strong[outcome]. The terms "predictor" and "outcome" are more general terminology than IV and DV, which are typically used in experimental contexts. However, they mean the same thing and can be used interchangeably.

=== How do regressions work?
<how-do-regressions-work>
Fundamentally, linear regressions involve plotting a line of best fit through the data. This line of best fit tells us something about the relationship between the two variables, including whether our predictor variable significant predicts the outcome.

See if you can take a guess where we should draw a line of best fit on the plot below:

#align(center)[#box(image("07-regressions_files/figure-typst/unnamed-chunk-11-1.svg"))]
You might have some good guesses, and there's every chance that you've drawn a line that fits the data points pretty well. But for this data, it's pretty obvious where the line would sit, and the data that we do work with won't always be as clear cut.

The line of best fit sits where #strong[the distance between the line and every point is minimised]. The difference between what we #emph[predict] (the line) and an actual data point is called a #strong[residual], which simply refers to #emph[error.] It makes sense then that to find the line of best fit, we want to place our line at the point where all of our possible residuals, or error, is minimised. If we didn't minimise our error, we couldn't say that it was the line of #emph[best] fit!

See the example below, where we have chosen 10 data points to illustrate. Each dot represents a single data point, while the solid blue line is our line of best fit. The dashed lines represent our residuals, or the difference between the blue line (what we #emph[predict]) and each actual data point.

#align(center)[#box(image("07-regressions_files/figure-typst/unnamed-chunk-12-1.svg"))]
We do this using the #strong[least squares] principle. In essence, we calculate a #strong[squared deviation] for each residual using the formula below - it might be familiar…

$ S S_(r e s) = Sigma \( y_i - macron(y)_i \)^2 $

Where $y_i$ is each individual (ith) value on the y-axis, and $macron(y)_i$ is the predicted y-value (i.e.~the regression line). Essentially, we calculate the residual for each data point, square it and add it all up.

From there, we would fine the line where all of these squared deviations are minimised. The actual #emph[minimising] part is something we won't concern ourselves with for this subject, because it's complicated - the key takeaway here is that the line of best fit sits at the point where we have minimised these residuals as much as possible.

== The regression equation
<the-regression-equation>
#block(fill: rgb("#f5f5f5"))[
Now we have a sense of how to place our line of best fit, what does that actually tell us about the relationship between our predictor and outcome? Here, we will look a bit closer at what the #emph[slope] of the line indicates.

]
=== Slopes and intercepts
<slopes-and-intercepts>
Coming back to our gestation versus birth weight example once again, let's now estimate a line of best fit through the data using our program of choice:

#align(center)[#box(image("07-regressions_files/figure-typst/unnamed-chunk-13-1.svg"))]
As we can see, there is clearly a positive relationship between gestation and birth weight - as we expected from us eyeballing the data. But recall that we're interested in seeing whether our predictor (gestation) does significantly predict the outcome (birth weight). How do we tell if this is the case? The #strong[slope] of the line of best fit tells us this, because it quantifies #strong[how much the outcome changes with each unit increase of the predictor].

An intuitive way to think about it is this: if the slope here was steep, it would tell us that every extra week of gestation would lead to a fairly noticeable increase in birth weight. If the slope was instead very gradual or flat, every extra week of gestation would lead to barely any change in birth weight - meaning that gestation would #emph[not] predict birth weight very well.

=== The regression equation
<the-regression-equation-1>
If you think back to high school, you may have learned something like y = mx + c in algebra to describe a straight line, where:

- #emph[m] denotes the slope, and
- #emph[c] denotes the intercept.

In linear regression, we use the same concepts to both describe our line and make predictions using it (more on that later). The key difference is that we change the letters a bit:

$ y = beta_0 + beta_1 x + epsilon.alt_i $

Let's break this down:

- y is simply our predicted value (i.e.~the line of best fit)
- $beta_0$ is our intercept (the c in y = mx + c)
- $x$ simply refers to our independent variable
- $beta_1$ is the slope for the independent variable - in other words, how much y increases for every unit increase of x. We also call this B
- $epsilon.alt_i$ is error (i.e.~our residuals), which is essentially random variation (due to sampling). This error should be normally distributed.

Keep this in mind for now - we'll come back to this later in the module!

=== Hypothesis testing in regressions
<hypothesis-testing-in-regressions>
When we conduct a linear regression, in part we're testing if the two variables are correlated. However, we're also testing whether our predictor significantly predicts our outcome, so our #emph[statistical] hypotheses are formulated around this idea. Our null and alternative hypotheses are therefore about the slope ($beta_1$):

- $H_0 : beta_1 = 0$, i.e.~the slope is 0

- $H_1 : beta_1 eq.not 0$, i.e.~the slope is not equal to 0

Consider the two graphs below. On the left is a graph where the line of best fit has a slope of 0 (the null). No matter what value X is, the value of Y is always the same (2.5 in this example) - in other words, X does not predict Y. The graph on the right side, on the other hand, is an example of the alternative hypothesis in this scenario. Here, X does clearly predict Y - as X increases, Y increases as well.

#align(center)[#box(image("img/w10_regression_hypotheses.svg"))]
But how do we actually test this? The answer is something we've seen before - we do a t-test!

We came across t-tests in context of comparing two means against each other. The logic here is exactly the same, except now we compare two slopes with each other - the slope we actually observe (B) minus the slope under the null hypothesis, which would be 0. We can use this logic to calculate a t-statistic using the below formula:

$ t = frac(B, S E_B) $

Where #emph[B] = observed slope and SE = standard error of B. This is the same formula as the calculation for a t-test, albeit that the top row is just B (because it is B - 0). We can do this for each predictor, and then use the same t-distribution to test whether this slope is significant - in other words, whether our predictor (IV) significantly predicts our outcome (DV).

== Assumption tests
<assumption-tests>
#block(fill: rgb("#f5f5f5"))[
As usual, there are several assumptions that we need to test for regressions. Some people call these #strong[regression diagnostics] - they mean the same as assumption testing.

]
=== Linearity
<linearity>
Believe it or not, for a linear regression your data should be… linear. Wild, right?

Bitter sarcasm aside, linearity is an important assumption that needs to be met before conducting a linear regression. Not all data will follow a linear pattern; some data may instead sit on a curve. Compare the two examples below, where one is clearly non-linear:

#align(center)[#box(image("07-regressions_files/figure-typst/unnamed-chunk-15-1.svg"))]
If the data shows no clear linear relationship between your IV and DV, it is likely because the two are weakly correlated (and so a linear regression would not be useful anyway). If instead the data lies on a very obvious curve, you can either:

- Transform the data to make it linear (but you must be clear about what this represents)
- Attempt to fit a curve and see whether this has more explanatory power, but madness lies this way for the unprepared

=== Homoscedasticity
<homoscedasticity>
The #strong[homoscedasticity] assumption is one that we've seen before - it is essentially a version of the equality of variance test. In a linear regression context, however, this assumption works a little bit differently; if this assumption is met, then the variance should be equal at all levels of our predictor (i.e.~the x-axis).

The easiest way to test this is to create a #strong[fitted vs residuals] graph. As the name implies, we take the fitted values for each level of the predictor in our data, and plot that against the residuals (fitted - actual). Here are some fitted vs residual plots for two sets of data. The data on the left has an even spread of variance as X increases, meaning that it is homoscedastic; the data on the right, on the other hand, spreads out like a cone. The data on the right therefore is likely #emph[heteroscedastic.]

#block[
#Skylighting(([#NormalTok("Warning: Removed 7 rows containing missing values or values outside the scale range");],
[#NormalTok("(`geom_point()`).");],));
]
#align(center)[#box(image("07-regressions_files/figure-typst/unnamed-chunk-16-1.svg"))]
There are a couple of ways to overcome this, such as either transforming the raw variables or weighting them.

=== Independence
<independence>
This one is the same - data points should be independent of each other. Like we have seen with other tests, this should ideally be a feature of good experimental design. In linear regression, a specific issue is autocorrelation - where the residuals between two values of X are not independent. If the residuals are #emph[not] independent, your data likely exhibits signs of #strong[autocorrelation] (i.e.~it is correlated with itself). This can distort the relationship between your IV and DV, and indicates that your data are connected through time.

We can test this using a test called the #strong[Durbin-Watson] test of autocorrelation. The Durbin-Watson test will estimate a coefficient/test statistic that quantifies the degree of autocorrelation (dependence) between observations in the data. The DW test statistic ranges from 0 to 4, with the following interpretations:

- A DW test statistic of \~2 indicates no autocorrelation.
- A DW test statistic of \< 2 indicate #emph[positive] autocorrelation - i.e.~one data point will positively influence the next.
- A DW test statistic of \> 2 indicates #emph[negative] autocorrelation.

The general principle of the Durbin-Watson test, therefore, is to have a test statistic close to 2 and (ideally) a non-significant result. The value of the test statistic is generally more useful than the significance of the test alone. A common guideline for interpreting this value is that a DW test statistic below 1 or above 3 is problematic, which we will also use for this subject.

The #NormalTok("DurbinWatsonTest()"); function from the DescTools package will let us test this quite easily.

#block[
#Skylighting(([#NormalTok("DescTools");#SpecialCharTok("::");#FunctionTok("DurbinWatsonTest");#NormalTok("(mod_1)");],));
#block[
#Skylighting(([],
[#NormalTok("    Durbin-Watson test");],
[],
[#NormalTok("data:  mod_1");],
[#NormalTok("DW = 2.0317, p-value = 0.5619");],
[#NormalTok("alternative hypothesis: true autocorrelation is greater than 0");],));
]
]
=== Normality
<normality>
The #strong[normality] assumption is the same here as it has been elsewhere - the residuals must be normally distributed. Here, it's a little bit easier to visualise what these 'residuals' are because we can calculate and see them. That being said, the way we test for these are exactly the same - either use a Q-Q plot or a Shapiro-Wilks test.

=== Multicollinearity
<multicollinearity>
The #strong[multicollinearity] (sometimes just called collinearity) assumption only applies to #strong[multiple regressions], where you have more than one predictor in your test. multicollinearity occurs when two predictors are too similar to one another (i.e.~they are highly correlated with each other. This becomes a problem at the individual predictor level, because what happens is that the effect of predictor A becomes muddled by predictor B - in other words, if two predictors are collinear, it becomes impossible to tell apart which one is contributing what to the regression.

There are three basic ways you can assess this.

- The simplest is to test a correlation between the two predictors. If they are very highly correlated (use r = .80 as a rule of thumb), this is likely to be a problem.
- The #strong[variance inflation factor (VIF)] is a more formal measure of multicollinearity. It is a single number, and a higher value means greater collinearity. If a VIF is #strong[greater than 5] this suggests an issue.
- #strong[Tolerance] is a related value to VIF - in fact, it is just 1 divided by the VIF - and works in much the same way, except smaller values mean greater collinearity. As a rule of thumb, if tolerance is smaller than 0.20 this suggests an issue.

To calculate VIF, you can use the #NormalTok("VIF()"); function from the #NormalTok("DescTools"); package - more on the relevant page.

== Linear regressions in R
<linear-regressions-in-r>
#block(fill: rgb("#f5f5f5"))[
Let's now turn to an example of how to do a linear regression in R.

]
=== Scenario
<scenario>
Musical sophistication describes the various ways in which people engage with music. In general, the more ways in which people engage with music, the more musically sophisticated they are.

One hypothesis is that years of musical training will clearly influence musical sophistication. While this is a bit of a no-brainer hypothesis, we'll test it using some example data.

#block[
#Skylighting(([#NormalTok("w10_goldmsi ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_10\"");#NormalTok(", ");#StringTok("\"w10_goldmsi.csv\"");#NormalTok(")) ");],));
#block[
#Skylighting(([#NormalTok("Rows: 74 Columns: 2");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("dbl (2): years_training, GoldMSI");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
#Skylighting(([#CommentTok("# This extra code is here for later");],
[#NormalTok("w10_goldmsi ");#OtherTok("<-");#NormalTok(" w10_goldmsi ");#SpecialCharTok("%>%");],
[#NormalTok("    ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("id =");#NormalTok(" ");#FunctionTok("seq");#NormalTok("(");#DecValTok("1");#NormalTok(", ");#FunctionTok("nrow");#NormalTok("(w10_goldmsi))");],
[#NormalTok("  ) ");],
[#FunctionTok("head");#NormalTok("(w10_goldmsi)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 3");],
[#NormalTok("  years_training GoldMSI    id");],
[#NormalTok("           <dbl>   <dbl> <int>");],
[#NormalTok("1              5      98     1");],
[#NormalTok("2              3      71     2");],
[#NormalTok("3              2      75     3");],
[#NormalTok("4              5      94     4");],
[#NormalTok("5              6      89     5");],
[#NormalTok("6              3      52     6");],));
]
]
=== Assumptions
<assumptions>
In R the linear regression needs to be coded first #emph[before] testing assumptions. Linear regression models can be built using #NormalTok("lm()");, and the same formula notation used in #NormalTok("aov()");:

#block[
#Skylighting(([#NormalTok("w10_goldmsi_lm ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(GoldMSI ");#SpecialCharTok("~");#NormalTok(" years_training, ");#AttributeTok("data =");#NormalTok(" w10_goldmsi)");],));
]
Let's test our assumptions from the previous page.

Linearity: a simple scatterplot tells us that our data probably is suitable for a linear regression:

#Skylighting(([#NormalTok("w10_goldmsi ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" years_training, ");#AttributeTok("y =");#NormalTok(" GoldMSI)");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("()");],));
#box(image("07-regressions_files/figure-typst/unnamed-chunk-20-1.svg"))

Independence: our DW test is significant (#emph[p] = .021), but our test statistic is 1.54. So, even though it's still significant it probably isn't much of a problem.#footnote[Given that this data was randomly generated, it probably is due to a simulation outlier more than anything.]

#block[
#Skylighting(([#FunctionTok("DurbinWatsonTest");#NormalTok("(w10_goldmsi_lm)");],));
#block[
#Skylighting(([],
[#NormalTok("    Durbin-Watson test");],
[],
[#NormalTok("data:  w10_goldmsi_lm");],
[#NormalTok("DW = 1.5409, p-value = 0.02123");],
[#NormalTok("alternative hypothesis: true autocorrelation is greater than 0");],));
]
]
Homoscedasticity: To plot a residual vs fitted plot in R, there are two ways:

- #NormalTok("plot(model, which = 1)");.

#Skylighting(([#FunctionTok("plot");#NormalTok("(w10_goldmsi_lm, ");#AttributeTok("which =");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],));
#box(image("07-regressions_files/figure-typst/unnamed-chunk-22-1.svg"))

- Using ggplot, but giving the model name instead of the data and setting the x and y aesthetics as follows:

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(w10_goldmsi_lm, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" .fitted, ");#AttributeTok("y =");#NormalTok(" .resid)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("Warning: `fortify(<lm>)` was deprecated in ggplot2 4.0.0.");],
[#NormalTok("ℹ Please use `broom::augment(<lm>)` instead.");],
[#NormalTok("ℹ The deprecated feature was likely used in the ggplot2 package.");],
[#NormalTok("  Please report the issue at <https://github.com/tidyverse/ggplot2/issues>.");],));
]
#box(image("07-regressions_files/figure-typst/unnamed-chunk-23-1.svg"))

Normality of residuals: Like #NormalTok("aov"); models, you can access the residuals from a given #NormalTok("lm()"); model, by using the name of the #NormalTok("lm"); object, followed by #NormalTok("$residuals");. This is useful for doing e.g.~a Shapiro-Wilks test on the residuals, or a Q-Q plot of residuals:

#block[
#Skylighting(([#FunctionTok("shapiro.test");#NormalTok("(w10_goldmsi_lm");#SpecialCharTok("$");#NormalTok("residuals)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  w10_goldmsi_lm$residuals");],
[#NormalTok("W = 0.98995, p-value = 0.8289");],));
]
]
#Skylighting(([#FunctionTok("qqnorm");#NormalTok("(w10_goldmsi_lm");#SpecialCharTok("$");#NormalTok("residuals)");],
[#FunctionTok("qqline");#NormalTok("(w10_goldmsi_lm");#SpecialCharTok("$");#NormalTok("residuals)");],));
#box(image("07-regressions_files/figure-typst/unnamed-chunk-25-1.svg"))

Our SW test is non-significant and our Q-Q plot looks ok, so this assumption is not violated.

=== Output
<output-6>
The output that R gives us for a linear regression comes in two parts: a test of the overall model, and a breakdown of the predictors and their slopes.

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(w10_goldmsi_lm)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = GoldMSI ~ years_training, data = w10_goldmsi)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("    Min      1Q  Median      3Q     Max ");],
[#NormalTok("-35.617  -9.227   2.025   9.773  33.666 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("               Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)      53.901      5.233  10.300 8.33e-16 ***");],
[#NormalTok("years_training    4.858      1.138   4.271 5.86e-05 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 14.61 on 72 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.2021,    Adjusted R-squared:  0.191 ");],
[#NormalTok("F-statistic: 18.24 on 1 and 72 DF,  p-value: 5.859e-05");],));
]
]
Let's start with the overall model. This tells us whether the regression model as a whole is significant. A couple of things to note here.

- $R^2$ is called the coefficient of determination. This value tells how much variance in the outcome is explained by the predictor. Our value is .202, which means that 20.2% of the variance in Gold-MSI scores is explained by years of training.
- The overall model test is essentially an ANOVA (we won't go too deep into why just yet!), which tells us whether the model is significant. In this case, it is (#emph[F]\(1, 72) = 18.24, #emph[p] \< .001).

Now we can look at the middle of the output, which gives the model coefficients. This part of the output tells us whether the predictors are significant. (Given the overall model is, with one predictor we'd expect this to be significant as well!).

The Estimate column gives us the #emph[B] coefficient, which is our slope. This tells us how much our outcome increases when our predictor increases by 1 unit.

From this, we can see that years of training is a significant predictor of Gold-MSI scores (#emph[t] = 4.27, #emph[p] \< .001); for every year of training, Gold-MSI scores increase by 4.86 (given by the value under Estimate, next to our predictor variable).

Finally, we can use the #NormalTok("confint"); function to return 95% confidence intervals on each regression slope:

#block[
#Skylighting(([#FunctionTok("confint");#NormalTok("(w10_goldmsi_lm)");],));
#block[
#Skylighting(([#NormalTok("                  2.5 %    97.5 %");],
[#NormalTok("(Intercept)    43.46925 64.332391");],
[#NormalTok("years_training  2.59058  7.125814");],));
]
]
Therefore, the 95% CI around the estimated regression coefficient of 4.86 is \[2.59, 7.13\].

Here is how we can write up these results. Note that for a regression, it is important to discuss both the overall model fit and the specific effect of the predictor.

#block(fill: rgb("#cce3c8"))[
We conducted a simple linear regression to examine whether years of training predicted Gold-MSI scores. The overall model was significant (#emph[F]\(1, 72) = 18.24, #emph[p] \< .001), with years of training explaining 20.2% of the variance in Gold-MSI scores ($R^2$ = .202). Years of training was a significant positive predictor of Gold-MSI scores (#emph[B] = 4.86, #emph[t] = 4.27, #emph[p] \< .001).

]
== Predictions
<predictions>
#block(fill: rgb("#f5f5f5"))[
A significant result from a linear regression tells us that our IV significantly predicts our outcome. We can actually use the results of the regression to make predictions about our outcome. This can be really useful in a number of contexts.

]
=== Revisiting the linear regression equation
<revisiting-the-linear-regression-equation>
Let's come back to the equation for a linear regression:

$ y = beta_0 + beta_1 x + epsilon.alt_i $

The results from the linear regression on the previous page allow us to construct a line of best fit. Using this line of best fit, we can make predictions about a participant's score on the dependent variable, given their score on the independent/predictor variable.

=== Building a regression equation
<building-a-regression-equation>
Here's the coefficient table from the previous page:

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(w10_goldmsi_lm)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = GoldMSI ~ years_training, data = w10_goldmsi)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("    Min      1Q  Median      3Q     Max ");],
[#NormalTok("-35.617  -9.227   2.025   9.773  33.666 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("               Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)      53.901      5.233  10.300 8.33e-16 ***");],
[#NormalTok("years_training    4.858      1.138   4.271 5.86e-05 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 14.61 on 72 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.2021,    Adjusted R-squared:  0.191 ");],
[#NormalTok("F-statistic: 18.24 on 1 and 72 DF,  p-value: 5.859e-05");],));
]
]
This table tells us the following things:

- The value of the intercept, $beta_0$, is 53.901
- The value of the slope, $beta_1$, is 4.858

Now we can make our equation as such:

$ G o l d M S I = 53.901 + \( 4.858 times Y e a r s \) $

We can now use this to predict scores!

=== An example prediction
<an-example-prediction>
Participant 47, highlighted in green below, has 5 years of musical training. What would their predicted Gold-MSI score to be?

#block[
#Skylighting(([#NormalTok("`geom_smooth()` using formula = 'y ~ x'");],));
]
#box(image("07-regressions_files/figure-typst/unnamed-chunk-29-1.svg"))

We can use the equation we just built to calculate a predicted score:

$ G o l d M S I = 53.901 + \( 4.858 times Y e a r s \) $ $ G o l d M S I = 53.901 + \( 4.858 times 5 \) $ $ = 78.191 $

Therefore, we would predict someone with 5 years of musical training to have a Gold-MSI score of 78.191. This is where the line sits. Notice however, that the predicted value is noticeably different to the participant's actual value (which in this instance is 56). The difference between the predicted and the actual value is called the residual - precisely the same residual that we aim to minimise when we fit a regression line to begin with (as well as the same residuals we do assumption tests on).

#block[
#callout(
body: 
[
While these predictions can be useful, there are two warnings that should be kept in mind.

- #strong[Extrapolation is dangerous]. While we might get data that appears linear, there is nothing to say that this data will remain linear outside of the bounds of our data. Extrapolating data refers to making inferences beyond the available range, and should be avoided.
- #strong[Don't forget that some data have logical boundaries]. For example, the Gold-MSI's maximum possible score is 126 across all scales. Any preditions that are higher than this are therefore quite easily nonsensical.

]
, 
title: 
[
Warning: How not to predict
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
== Multiple regression: Theory
<multiple-regression-theory>
#block(fill: rgb("#f5f5f5"))[
If all of that stuff on the previous page made sense then great! You're now ready to tackle multiple regressions, which are an extension of the simple linear regression. You'll see that much of the same stuff applies here, but a few things change…

]
=== Multiple regression
<multiple-regression>
Multiple regression is used when we want to test multiple predictors against an outcome variable. It'd be a safe bet to say that multiple regression and its various forms are probably one of the most used statistical tests in music psychology literature as a whole - you'll see them everywhere! No introduction to linear regression would really be complete without at least scratching the surface of multiple regression.

The name "multiple regression" is actually a fairly generic term in some respects, as it describes any instance of regression with two or more predictors. I say that because there are several forms of multiple regression, such as:

- Standard multiple regression, which we will cover in this subject
- Hierarchical multiple regression, where you split your analysis into blocks
- Stepwise multiple regression, where algorithms attempt to select the best predictors
- And more!

=== The regression equation, once again
<the-regression-equation-once-again>
Recall that in a simple linear regression, we had this formula to describe the line of best fit:

$ y = beta_0 + beta_1 x + epsilon.alt_i $

In a multiple regression, we work with an extension of this formula. The key part here is the part of the equation labelled $beta_1 x$ - this is the part of the equation that relates to the individual predictor and its slope (i.e.~how it predicts the outcome). We extend this in a multiple regression. For example, say we now had two predictors:

$ y = beta_0 + beta_1 x_1 + beta_2 x_2 + epsilon.alt_i $

We now have a term for our first predictor $beta_1 x_1$ and for our second: $beta_2 x_2$.

- x1 and x2 simply mean predictor 1 and predictor 2.
- The betas here are still regression slopes; the subscript numbers just indicate which predictor they correspond to.

From here on, much of the same reasoning that we saw in the early pages of this module apply. The primary hypotheses are now about whether each slope is significantly different from zero - which would indicate whether each predictor does significantly predict the outcome.

=== Assumption testing in multiple regressions
<assumption-testing-in-multiple-regressions>
All of the following assumption tests apply:

- Linearity
- Independence
- Homoscedasticity
- Normality
- Multicollinearity

We'll test these on the next page!

== Multiple regressions in R
<multreg-intro>
#block(fill: rgb("#f5f5f5"))[
Phew - we're almost there! Let's round out this week's module by doing a standard multiple regression in Jamovi.

]
=== Example data
<example-data-5>
Let's look at a real set of data from Rakei et al.~(2022). Their study looked at what predicts how prone people are to flow - the experience of being 'in the moment' and extremely focused while doing a task, such as performing. They measured a wide range of personality and emotion-related variables, but we'll focus on just a subset here:

- Trait anxiety: broadly, refers to people's tendency to feel anxious
- Openness to experience: a personality trait that describes how likely people are to seek new experiences
- DFS\_Total: a measure of proneness to flow.

Let's see if trait anxiety and openness predict flow proneness.

#block[
#Skylighting(([#NormalTok("w10_flow ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_10\"");#NormalTok(", ");#StringTok("\"w10_flow.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 811 Columns: 6");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("dbl (6): id, age, GoldMSI, DFS_Total, trait_anxiety, openness");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
To build a multiple regression model in R, we simply need to add (literally) more terms to #NormalTok("lm()");:

#block[
#Skylighting(([#NormalTok("w10_flow_lm ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(DFS_Total ");#SpecialCharTok("~");#NormalTok(" trait_anxiety ");#SpecialCharTok("+");#NormalTok(" openness, ");#AttributeTok("data =");#NormalTok(" w10_flow)");],));
]
=== Assumption checks
<assumption-checks-5>
Our Durbin-Watson test suggests no issues with independence of observations.

#block[
#Skylighting(([#FunctionTok("DurbinWatsonTest");#NormalTok("(w10_flow_lm)");],));
#block[
#Skylighting(([],
[#NormalTok("    Durbin-Watson test");],
[],
[#NormalTok("data:  w10_flow_lm");],
[#NormalTok("DW = 1.9456, p-value = 0.2182");],
[#NormalTok("alternative hypothesis: true autocorrelation is greater than 0");],));
]
]
The Shapiro-Wilks test suggests that our normality assumption is violated - though if you look at the relevant Q-Q plot, it doesn't appear to be very severe.

#block[
#Skylighting(([#FunctionTok("shapiro.test");#NormalTok("(w10_flow_lm");#SpecialCharTok("$");#NormalTok("residuals)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  w10_flow_lm$residuals");],
[#NormalTok("W = 0.99311, p-value = 0.0008488");],));
]
]
The residuals-fitted plot for our data looks ok - no obvious conical shape, suggesting that the homoscedasticity assumption is intact.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(w10_flow_lm, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" .fitted, ");#AttributeTok("y =");#NormalTok(" .resid)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("()");],));
#box(image("07-regressions_files/figure-typst/unnamed-chunk-34-1.svg"))

Lastly, our multicollinearity statistics look good - no violations suggested here.

#block[
#Skylighting(([#CommentTok("# Variance");],
[#NormalTok("DescTools");#SpecialCharTok("::");#FunctionTok("VIF");#NormalTok("(w10_flow_lm)");],));
#block[
#Skylighting(([#NormalTok("trait_anxiety      openness ");],
[#NormalTok("     1.025955      1.025955 ");],));
]
#Skylighting(([#CommentTok("# Tolerance");],
[#DecValTok("1");#SpecialCharTok("/");#NormalTok("DescTools");#SpecialCharTok("::");#FunctionTok("VIF");#NormalTok("(w10_flow_lm)");],));
#block[
#Skylighting(([#NormalTok("trait_anxiety      openness ");],
[#NormalTok("    0.9747012     0.9747012 ");],));
]
]
=== Output
<output-7>
Let's start as always by taking a look at our output. Our regression explains 13.6 of the variance in flow proneness ($R^2$ = .136), and our overall model is significant (#emph[F]\(2, 808) = 63.81, #emph[p] \< .001).

With that in mind, let's turn to our individual predictors. Remember, now we have two predictors to consider - and we need to interpret them individually as well.

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(w10_flow_lm)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = DFS_Total ~ trait_anxiety + openness, data = w10_flow)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("    Min      1Q  Median      3Q     Max ");],
[#NormalTok("-16.596  -2.331  -0.151   2.308  12.794 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("              Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)   32.65078    1.13377  28.798  < 2e-16 ***");],
[#NormalTok("trait_anxiety -0.11116    0.01278  -8.697  < 2e-16 ***");],
[#NormalTok("openness       0.83372    0.14538   5.735 1.38e-08 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 3.705 on 808 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.1364,    Adjusted R-squared:  0.1343 ");],
[#NormalTok("F-statistic: 63.81 on 2 and 808 DF,  p-value: < 2.2e-16");],));
]
#Skylighting(([#FunctionTok("confint");#NormalTok("(w10_flow_lm)");],));
#block[
#Skylighting(([#NormalTok("                   2.5 %      97.5 %");],
[#NormalTok("(Intercept)   30.4252962 34.87625896");],
[#NormalTok("trait_anxiety -0.1362446 -0.08606874");],
[#NormalTok("openness       0.5483533  1.11907751");],));
]
]
We can see that both trait anxiety and openness are significant predictors of flow proneness, but interpreting the direction is also really important here. For that, we turn to our estimates:

- The estimate for trait anxiety is #emph[B] = -.111 (95% CI \[-.136, .086\]), suggesting that higher trait anxiety predicts lower flow proneness (#emph[p] \< .001)
- On the other hand, the estimate for openness is #emph[B] = .834 (95% CI \[.548, 1.119\]), suggesting that higher openness predicts higher flow proneness (#emph[p] \< .001).

Therefore, we can conclude that both are significant predictors and have opposite effects to each other. We can write this up as follows:

#block(fill: rgb("#cce3c8"))[
We ran a multiple regression with trait anxiety and openness as predictors, and flow proneness as an outcome. The overall regression model was significant (#emph[F]\(2, 808) = 63.81, #emph[p] \< .001), and explained 13.6% of the variance in flow proneness. Trait anxiety significantly predicted flow proneness (#emph[B] = -.11, 95% CI \[-.14, -.09\], #emph[t] = -8.70, #emph[p] \< .001); higher trait anxiety predicted lower flow proneness. Openness was also a significant predictor (#emph[B] = .83, 95% CI \[.55, 1.12\], #emph[t] = 5.74, #emph[p] \< .001); higher openness predicted higher flow proneness.

]
But there's one more thing we can consider here…

=== Comparing predictive strength
<comparing-predictive-strength>
When we do a multiple regression, we can actually identify which of our predictors is the strongest predictor of the outcome.

Our estimate column alone won't tell us that, because these are #strong[unstandardised coefficients]. They are unstandardised because they describe the relationship in terms of the original units of each measure. An increase of 1 unit on trait anxiety is not necessarily the same thing as a 1 unit increase in openness because they are on different scales, so we can't compare them directly!

However, if we were to #strong[standardise] these coefficients, we would then bring them all into the same scale (think back to z-scores!) - which would allow us to directly compare which predictor leads to a greater change in the outcome. These are simply regression coefficients that have been standardised, meaning that they are all on the same scale. Jamovi will calculate a #strong[standardised estimate] (sometimes called #strong[standardised coefficient]), which is presented in the rightmost column of the above table. Standardised estimates are denoted as #strong[beta] ($beta$), and thus are sometimes called #strong[standard betas].

Standard betas allow us to interpret our coefficients in terms of changes in #strong[standard deviations]\; namely, a 1 SD increase in predictor X leads to a $beta$ SD change in predictor Y.

In R, we need to use an extra function to calculate standard betas. We can call on the #NormalTok("StdCoef()"); function from the #NormalTok("DescTools"); package:

#block[
#Skylighting(([#FunctionTok("StdCoef");#NormalTok("(w10_flow_lm)");],));
#block[
#Skylighting(([#NormalTok("               Estimate* Std. Error*  df");],
[#NormalTok("(Intercept)    0.0000000   0.0000000 808");],
[#NormalTok("trait_anxiety -0.2879944   0.0331142 808");],
[#NormalTok("openness       0.1899044   0.0331142 808");],
[#NormalTok("attr(,\"class\")");],
[#NormalTok("[1] \"coefTable\" \"matrix\"   ");],));
]
]
If you want confidence intervals around the standardised coefficients, the #NormalTok("standardize_parameters()"); function from the #NormalTok("effectsize"); package will do this for you:

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(effectsize)");],));
#block[
#Skylighting(([],
[#NormalTok("Attaching package: 'effectsize'");],));
]
#block[
#Skylighting(([#NormalTok("The following objects are masked from 'package:rstatix':");],
[],
[#NormalTok("    cohens_d, eta_squared");],));
]
#Skylighting(([#FunctionTok("standardize_parameters");#NormalTok("(w10_flow_lm)");],));
#block[
#Skylighting(([#NormalTok("# Standardization method: refit");],
[],
[#NormalTok("Parameter     | Std. Coef. |         95% CI");],
[#NormalTok("-------------------------------------------");],
[#NormalTok("(Intercept)   |   9.28e-16 | [-0.06,  0.06]");],
[#NormalTok("trait anxiety |      -0.29 | [-0.35, -0.22]");],
[#NormalTok("openness      |       0.19 | [ 0.12,  0.25]");],));
]
]
Alternatively, we can simply standardise our predictors before running our regression (which is a lot easier in R than in other programs):

#block[
#Skylighting(([#CommentTok("# Standardise predictors");],
[],
[#NormalTok("w10_flow_std ");#OtherTok("<-");#NormalTok(" w10_flow ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("trait_anxiety =");#NormalTok(" ");#FunctionTok("scale");#NormalTok("(trait_anxiety),");],
[#NormalTok("    ");#AttributeTok("openness =");#NormalTok(" ");#FunctionTok("scale");#NormalTok("(openness),");],
[#NormalTok("    ");#AttributeTok("DFS_Total =");#NormalTok(" ");#FunctionTok("scale");#NormalTok("(DFS_Total)");],
[#NormalTok("  )");],
[],
[#NormalTok("w10_flow_lm_std ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(DFS_Total ");#SpecialCharTok("~");#NormalTok(" trait_anxiety ");#SpecialCharTok("+");#NormalTok(" openness, ");#AttributeTok("data =");#NormalTok(" w10_flow_std)");],
[#FunctionTok("summary");#NormalTok("(w10_flow_lm_std)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = DFS_Total ~ trait_anxiety + openness, data = w10_flow_std)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("    Min      1Q  Median      3Q     Max ");],
[#NormalTok("-4.1675 -0.5855 -0.0379  0.5795  3.2128 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("                Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)    9.281e-16  3.267e-02   0.000        1    ");],
[#NormalTok("trait_anxiety -2.880e-01  3.311e-02  -8.697  < 2e-16 ***");],
[#NormalTok("openness       1.899e-01  3.311e-02   5.735 1.38e-08 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 0.9304 on 808 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.1364,    Adjusted R-squared:  0.1343 ");],
[#NormalTok("F-statistic: 63.81 on 2 and 808 DF,  p-value: < 2.2e-16");],));
]
#Skylighting(([#FunctionTok("confint");#NormalTok("(w10_flow_lm_std)");],));
#block[
#Skylighting(([#NormalTok("                    2.5 %      97.5 %");],
[#NormalTok("(Intercept)   -0.06413295  0.06413295");],
[#NormalTok("trait_anxiety -0.35299439 -0.22299437");],
[#NormalTok("openness       0.12490436  0.25490437");],));
]
]
This means that we can just compare the numbers of the standardised estimates (ignoring positive/negative signs) to see which one is the greatest predictor of the outcome. In the example above, trait anxiety has a standard coefficient of .288, whereas openness has a standard coefficient of .190. Trait anxiety is therefore a stronger predictor of flow proneness, because a 1 standard deviation increase in trait anxiety leads to a greater increase in flow proneness - namely, a change of .288 standard deviations.

#part[Part III: Advanced methods]
= Factorial ANOVAs
<factorial-anova>
In this module we return to the humble ANOVA, and to working with categorical predictors again. Specifically, we move beyond just having one categorical predictor in an ANOVA model to having two (and all of the complexities that come with doing so). We'll also take a look at interactions, which form a crucial part of more complex models specifying relationships between our predictors.

This module covers:

- Two-way between-subjects ANOVA
- Two-way repeated measures ANOVA
- TWo-way mixed ANOVA
- Three-way between-subjects ANOVA

== Introduction
<factorial-intro>
In Week 9 we talked about analyses of variance - tests for comparing means across one categorical IV/predictor (typically with at least 3 levels) on one continuous outcome. In this extension module we move to some more complex ANOVA models - specifically two-way ANOVAs, where we have two categorical predictors and one continuous outcome. The main goal is still largely the same - comparing means across groups - but becomes a bit more complex with the involvement of two variables. We'll also briefly consider the instance of a three-way ANOVA (i.e.~three predictors), but won't spend too much time on this for good reason. We'll also talk briefly about some statistical concepts that we haven't covered in the main subject content, specifically about interactions and contrasts.

By the end of this module you should be able to:

- Describe what an interaction is
- Conduct and interpret an omnibus two-way ANOVA
- Distinguish between post-hoc tests, simple effects tests and planned contrasts
- Attempt to think about a three-way ANOVA (but see warnings on the relevant page)

== Factorial designs
<factorial-designs>
In Week 9, when we talk about ANOVAs we conduct one-way ANOVAs. These tests from Week 9 are called one-way ANOVAs because there is only one IV with multiple levels being tested. However, in many research designs we will want to test the effect of two or more categorical variables at the same time (for example, experimental conditions or variables that capture important categories, such as participant sex).

When we want to test the effect of more than one IV, we start getting into what we call #strong[factorial ANOVAs]. Factorial ANOVAs are used when we have two or more IVs, each with at least two levels per variable. This is common in a lot of research designs, where either multiple categorical variables are collected as part of the data collection phase or categorical variables are created as part of the analysis process.

We will talk about this more on the next page, but factorial designs are particularly useful for testing interactions, and the effects of both of your IVs together.

When reporting results for factorial designs, it is expected that you report how many levels each variable had. For instance, let's say your two IVs are participant sex (male and female) and experimental group (group A, B and C). If you were to test this factorial design, there are a couple of ways you could report this:

- A Sex (2) x Group (3) factorial ANOVA
- A 2 x 3 factorial ANOVA
- A Sex x Group (2 x 3) factorial ANOVA

The first one is the preferable because it lays out the conditions clearly.

=== What is an interaction?
<what-is-an-interaction>
Pretend you've been enacting a singing intervention in a school of kids, where one group of kids have been singing daily and another group have not been. You're interested in whether the singing intervention has an effect on their wellbeing. By and large, the singing intervention does - there is a clear difference between the kids who get singing sessions and kids who don't. However, you notice that how effective the intervention is depends on whether they are boys or girls. The girls appear to benefit the most, while the boys don't seem to as much. In other words, the effectiveness of the intervention is contingent on the biological sex of the child.

This is an example of an interaction, where the effect of one IV depends on the effect of another IV. The consequence of an interaction is that the two IVs both influence the DV together (in a non-additive manner). Interactions can be important for understanding how certain phenomena work.

Consider the two plots below, that show the relationship between two predictors (X and Group) and one outcome (on the y-axis).

- In the graph on the left, there is a clear difference between groups 1 and 2. There is also a clear difference between A, B and C on X; however, this is constant.
- In the graph on the right, there's still a clear difference between groups 1 and 2. However, the difference is greater between different groups. For group 1, there is no change from A to C, but there is for group 2; in other words, the effect of X depends on the effect of Group.

#box(image("img/factorial_graph.svg"))

The easiest way of demonstrating an interaction is by using an interaction plot, like the one above. This kind of graph plots means as dots, and joins different groups/IVs together by lines. Interaction plots with error bars (e.g.~+/- 1 standard error) provide the clearest way of graphing of an interaction effect.

=== Testing for interactions
<testing-for-interactions>
We can test for interactions when we have at least two independent variables/predictors, using both ANOVAs and regressions. The majority of this module will focus on instances with two predictors in an ANOVA context, as they are easiest to conceptualise.

By default, if we have two predictors - A, and B, and an outcome, Y - our model will have the following terms:

- A, or the main effect of A (i.e.~of A only)
- B, the other main effect
- A x B, which is our interaction effect

Therefore, we end up with two types of effects that we need to interpret: main effects, and interaction effects. An interaction effect is what we call a higher-order term, in that it is a more complex term in our model. We test the significance of each term, giving us three p-values and sets of test statistics.

== Simple effects tests
<simple-effects-tests>
Remember from the previous page that when we have two predictors, we end up with three model terms:

- A, a #strong[main effect]
- B, a #strong[main effect]
- A x B, which is our #strong[interaction effect]

Therefore, we end up with two types of effects that we need to interpret: main effects, and interaction effects. An interaction effect is what we call a higher-order term, in that it is a more complex term in our model. We test the significance of each term, giving us three p-values and sets of test statistics.

Here's an example of a two-way ANOVA with a significant interaction. Notice that there are three effects here: one for gender, one for education and the gender x education level interaction. (We'll go through how to run these models a bit later.)

#block[
#block[
#Skylighting(([#NormalTok("Anova Table (Type 3 tests)");],
[],
[#NormalTok("Response: score");],
[#NormalTok("                  Effect    df  MSE          F  pes p.value");],
[#NormalTok("1                 gender 1, 52 0.30       0.59 .011    .448");],
[#NormalTok("2        education_level 2, 52 0.30 189.17 *** .879   <.001");],
[#NormalTok("3 gender:education_level 2, 52 0.30    7.34 ** .220    .002");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '+' 0.1 ' ' 1");],));
]
]
How do we interpret this? Clearly, we have no main effect of gender (#emph[p] = .448) but we do have an effect of education level (#emph[p] \< .001). We also have a significant interaction term: gender x education (#emph[p] = .002).

Here is where something called the #strong[principle of marginality] kicks in. The principle of marginality, states that if two variables interact with each other, the main effects of each variable are marginal to their interaction. In more simple terms, this means that a significant interaction is a better explanation of the main effects than the main effects themselves. In context, this means that the significant effect of education level is actually best explained by decomposing the gender x education level interaction. Therefore, if you have a significant interaction you want to break this down first. If the interaction is not significant, you can run post-hocs on the main effects only.

But like a regular ANOVA, this only tells us that there is an interaction. How do we find out which means are different?

=== Simple effects tests
<simple-effects-tests-1>
One option is to conduct post-hoc tests like normal, and run post-hocs on the interaction term. But this is not necessarily meaningful:

#block[
#block[
#Skylighting(([#NormalTok("  Tukey multiple comparisons of means");],
[#NormalTok("    95% family-wise confidence level");],
[],
[#NormalTok("Fit: aov(formula = tmp_formula, data = dat.ret, contrasts = contrasts)");],
[],
[#NormalTok("$gender");],
[#NormalTok("                 diff         lwr       upr     p adj");],
[#NormalTok("male-female 0.1932143 -0.09680436 0.4832329 0.1870895");],
[],
[#NormalTok("$education_level");],
[#NormalTok("                         diff       lwr        upr     p adj");],
[#NormalTok("school-college     -0.7573684 -1.187898 -0.3268386 0.0002637");],
[#NormalTok("university-college  2.4944417  2.069328  2.9195559 0.0000000");],
[#NormalTok("university-school   3.2518102  2.826696  3.6769243 0.0000000");],
[],
[#NormalTok("$`gender:education_level`");],
[#NormalTok("                                        diff        lwr          upr     p adj");],
[#NormalTok("male:college-female:college       -0.2396667 -0.9873581  0.508024749 0.9317495");],
[#NormalTok("female:school-female:college      -0.7220000 -1.4497494  0.005749384 0.0529764");],
[#NormalTok("male:school-female:college        -1.0363333 -1.7840247 -0.288641918 0.0019203");],
[#NormalTok("female:university-female:college   1.9430000  1.2152506  2.670749384 0.0000000");],
[#NormalTok("male:university-female:college     2.8290000  2.1012506  3.556749384 0.0000000");],
[#NormalTok("female:school-male:college        -0.4823333 -1.2300247  0.265358082 0.4086560");],
[#NormalTok("male:school-male:college          -0.7966667 -1.5637819 -0.029551460 0.0374890");],
[#NormalTok("female:university-male:college     2.1826667  1.4349753  2.930358082 0.0000000");],
[#NormalTok("male:university-male:college       3.0686667  2.3209753  3.816358082 0.0000000");],
[#NormalTok("male:school-female:school         -0.3143333 -1.0620247  0.433358082 0.8132166");],
[#NormalTok("female:university-female:school    2.6650000  1.9372506  3.392749384 0.0000000");],
[#NormalTok("male:university-female:school      3.5510000  2.8232506  4.278749384 0.0000000");],
[#NormalTok("female:university-male:school      2.9793333  2.2316419  3.727024749 0.0000000");],
[#NormalTok("male:university-male:school        3.8653333  3.1176419  4.613024749 0.0000000");],
[#NormalTok("male:university-female:university  0.8860000  0.1582506  1.613749384 0.0087499");],));
]
]
A more targeted approach is to conduct simple effects tests. Simple effects tests are a form of pairwise comparisons that are run to break down an interaction. It involves running pairwise comparisons between one predictor at every level of the other predictor.

Using the example above, this might include running pairwise comparisons between education levels for males and females separately:

#block[
#block[
#Skylighting(([#NormalTok("gender = female:");],
[#NormalTok(" contrast             estimate    SE df t.ratio p.value");],
[#NormalTok(" college - school        0.722 0.246 52   2.935  0.0050");],
[#NormalTok(" college - university   -1.943 0.246 52  -7.899 <0.0001");],
[#NormalTok(" school - university    -2.665 0.246 52 -10.834 <0.0001");],
[],
[#NormalTok("gender = male:");],
[#NormalTok(" contrast             estimate    SE df t.ratio p.value");],
[#NormalTok(" college - school        0.797 0.259 52   3.073  0.0034");],
[#NormalTok(" college - university   -3.069 0.253 52 -12.143 <0.0001");],
[#NormalTok(" school - university    -3.865 0.253 52 -15.295 <0.0001");],));
]
]
Or, to spin it the other way, you might compare males and females for each education level separately:

#block[
#block[
#Skylighting(([#NormalTok("education_level = college:");],
[#NormalTok(" contrast      estimate    SE df t.ratio p.value");],
[#NormalTok(" female - male    0.240 0.253 52   0.948  0.3473");],
[],
[#NormalTok("education_level = school:");],
[#NormalTok(" contrast      estimate    SE df t.ratio p.value");],
[#NormalTok(" female - male    0.314 0.253 52   1.244  0.2191");],
[],
[#NormalTok("education_level = university:");],
[#NormalTok(" contrast      estimate    SE df t.ratio p.value");],
[#NormalTok(" female - male   -0.886 0.246 52  -3.602  0.0007");],));
]
]
Generally, it is wise to run simple effects tests both ways - as this decomposes the interaction into something that is interpretable. This is usually guided by theoretical reasons (i.e.~a hypothesis about which simple effects to run). Of course, a good graph will tell the rest of the story:

#box(image("08-factorial-anovas_files/figure-typst/unnamed-chunk-6-1.svg"))

== R-specific considerations
<r-specific-considerations>
This page discusses some basic considerations about performing factorial ANOVAs in R.

=== The #NormalTok("afex"); package
<the-afex-package>
In the sections on one-way ANOVAs we largely stuck to using base R's #NormalTok("aov()"); function, or the #NormalTok("anova_test()"); function from the #NormalTok("rstatix"); package. While we can absolutely continue to use these for factorial ANOVAs, one problem is that factorial ANOVAs are inherently more complex models than their one-way progenitors. For instance, #NormalTok("aov()"); only really works with #strong[balanced] designs, which is where every cell (i.e.~group x group combination of your IVs/predictors) has the same number of participants.

To use an example, a 2 x 2 ANOVA where each of the four possibilities (e.g.~Level 1 Variable A + Level 1 Variable B…) has 20 participants is a balanced design. In contrast, if A1-B2 had 40 participants and the other possibilities had 20 participants, this would be an unbalanced design. Unbalanced designs introduce several complexities for ANOVAs.

The #NormalTok("afex"); package is designed for factorial ANOVAs in particular. It provides a very nice and convenient way of running factorial ANOVAs in a way that's not too hard, while still being flexible enough for more hardcore R users.

In particular, the function you will want to keep in mind is #NormalTok("aov_ez()");.

=== Writing interactions in R
<writing-interactions-in-r>
The #NormalTok("aov_ez()"); function that was just mentioned doesn't use the same kind of formula notation that we saw in the other test sections, and that's to make it easier to run. However, these analyses absolutely can be recreated in formula notation, and you will see many instances of this.

Recall the basic layout for a formula in R:

#block[
#Skylighting(([#FunctionTok("lm");#NormalTok("(outcome ");#SpecialCharTok("~");#NormalTok(" predictor, ");#AttributeTok("data =");#NormalTok(" dataset)");],
[#FunctionTok("aov");#NormalTok("(outcome ");#SpecialCharTok("~");#NormalTok(" predictor, ");#AttributeTok("data =");#NormalTok(" dataset)");],));
]
To extend this to two variables with no interaction, you can simply add the second predictor as such:

#block[
#Skylighting(([#FunctionTok("aov");#NormalTok("(outcome ");#SpecialCharTok("~");#NormalTok(" predictor_1 ");#SpecialCharTok("+");#NormalTok(" predictor_2, ");#AttributeTok("data =");#NormalTok(" dataset)");],));
]
To code for an interaction term, however, there either needs to be an explicit term for the interaction (denoted using a colon between the two interaction variables):

#block[
#Skylighting(([#FunctionTok("aov");#NormalTok("(outcome ");#SpecialCharTok("~");#NormalTok(" predictor_1 ");#SpecialCharTok("+");#NormalTok(" predictor_2 ");#SpecialCharTok("+");#NormalTok(" predictor_1");#SpecialCharTok(":");#NormalTok("predictor_2, ");#AttributeTok("data =");#NormalTok(" dataset)");],));
]
OR as the shorthand for above, which uses the asterisk. Note that the asterisk will include both the interaction term and all of its main effects (a la principle of marginality):

#block[
#Skylighting(([#FunctionTok("aov");#NormalTok("(outcome ");#SpecialCharTok("~");#NormalTok(" predictor_1 ");#SpecialCharTok("*");#NormalTok(" predictor_2, ");#AttributeTok("data =");#NormalTok(" dataset)");],));
]
For what we do in this section, this is ok - but you may find in certain circumstances that you don't want all of these terms together, so the first approach will let you specify what terms to include in the model.

=== Simple effects tests in R
<simple-effects-tests-in-r>
Simple effects tests, weirdly, are difficult to do in Jamovi - the gamlj module in Jamovi will do simple effects tests for linear models (which includes ANOVAs), but it's difficult to do so for anything other than a two-way between-groups ANOVA without some prerequisite knowledge on linear mixed models.

In R, simple effects are relatively easy to estimate through the use of the #NormalTok("emmeans"); package. All we need to do is just extend our #NormalTok("emmeans"); calls that we have been using for one-way ANOVAs to incorporate a second variable.

Imagine an ANOVA model named #NormalTok("model_aov"); and two predictors named #NormalTok("A"); and \`B. Recall the basic syntax for generating comparisons for a one-way ANOVA:

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(model_aov, ");#SpecialCharTok("~");#NormalTok(" A)");],));
]
To run this as a simple effects test, we simply need to tell #NormalTok("emmeans"); to conduct these comparisons by another variable. This can be easily done by specifying the #NormalTok("by"); argument in #NormalTok("emmeans");:

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(model_aov, ");#SpecialCharTok("~");#NormalTok(" A, ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"B\"");#NormalTok(")");],));
]
This will estimate the EM means for every level of A, at each level of B. To run simple effects tests for variable two, the variable names simply need to be swapped.

Just like before, we can pipe from from #NormalTok("emmeans()"); to #NormalTok("pairs()");:

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(model_aov, ");#SpecialCharTok("~");#NormalTok(" A, ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"B\"");#NormalTok(") ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
]
Final note on this matter: Rstatix does provide a function called #NormalTok("emmeans_test()"); to perform a similar test. However, using the original #NormalTok("emmeans"); package and its functions give you much greater flexibility, so it helps to learn how to use this as is.

== Two-way between groups ANOVA
<two-way-between-groups-anova>
=== Introduction
<introduction>
Two-way between-groups ANOVAs are used when you have two categorical IVs, both of which are between-groups variables. For example, you might have the following IVs:

- Sex: Male or female
- Experimental group: Group A or Group B

There are four possibilities here - males in Group A, females in Group A, males in Group B and females in Group B. These are mutually exclusive categories in the context of this design.

=== Example
<example-2>
One of the earliest modern studies on music's effect on consumer behaviour came from #link("https://doi.org/10.1037/0021-9010.84.2.271")[Hargreaves et al.~1999], who played either French or German music in a wine shop. They looked at how much people spent on French and German wines, and tested to see whether the effect of background music and wine type had an effect on spending.

We're going to step through an analogous (fictional) example, inspired by the Hargreaves et al.~(1999) study. Pretend we played either country or classical music in a supermarket, and observed moments when people purchased beer or wine (We're going to assume we've removed people who bought both beer and wine together.) . In this hypothetical scenario, we might expect a similar 'priming' effect of the background music - that is, maybe the type of music will prime people to behave in different ways. Maybe, for instance, a certain kind of music will make people spend more, but this might depend on what type of alcohol they are buying.

Our research question in this instance is, Does the effect of music on alcohol spend depend on the type of alcohol purchased?

Therefore, we have two between-groups IVs:

- #strong[Alcohol type] being purchased: was the person buying beer or wine?
- #strong[Genre] of background music: was country or classical music being played at the time?

We're interested in whether these two variables have an effect on how much people spend (our dependent variable/outcome). This can be described as a #strong[two-way ANOVA] (alcohol type x genre), or alternatively as a #strong[2 x 2 ANOVA] - more specifically, 2 (beer, wine) x 2 (country, classical) ANOVA between alcohol type and genre.

Let's start by generating descriptives and a graph to visualise what we're looking at:

#block[
#Skylighting(([#NormalTok("twoway_alcohol ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"factorial\"");#NormalTok(", ");#StringTok("\"twoway_bganova.csv\"");#NormalTok("))");],));
]
#box(image("08-factorial-anovas_files/figure-typst/unnamed-chunk-15-1.svg"))

#block[
#Skylighting(([#NormalTok("twoway_alcohol ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(alcohol_type, genre) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("n =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("mean =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(spend, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("median =");#NormalTok(" ");#FunctionTok("median");#NormalTok("(spend, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("sd =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(spend, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("se =");#NormalTok(" sd");#SpecialCharTok("/");#NormalTok("n");],
[#NormalTok("  ) ");],));
#block[
#Skylighting(([#NormalTok("`summarise()` has regrouped the output.");],
[#NormalTok("ℹ Summaries were computed grouped by alcohol_type and genre.");],
[#NormalTok("ℹ Output is grouped by alcohol_type.");],
[#NormalTok("ℹ Use `summarise(.groups = \"drop_last\")` to silence this message.");],
[#NormalTok("ℹ Use `summarise(.by = c(alcohol_type, genre))` for per-operation grouping");],
[#NormalTok("  (`?dplyr::dplyr_by`) instead.");],));
]
#block[
#Skylighting(([#NormalTok("# A tibble: 4 × 7");],
[#NormalTok("# Groups:   alcohol_type [2]");],
[#NormalTok("  alcohol_type genre         n  mean median    sd     se");],
[#NormalTok("  <chr>        <chr>     <int> <dbl>  <dbl> <dbl>  <dbl>");],
[#NormalTok("1 beer         classical    49  36.1   35.9 0.981 0.0200");],
[#NormalTok("2 beer         country      51  29.9   29.8 1.03  0.0202");],
[#NormalTok("3 wine         classical    47  39.5   39.4 0.993 0.0211");],
[#NormalTok("4 wine         country      53  26.9   27.0 1.03  0.0195");],));
]
]
=== Assumption testing
<assumption-testing>
As we have previously seen with ANOVAs in R, to test some of our assumptions we first need to build our ANOVA. Note that here, we use the #NormalTok("aov_ez()"); function from the #NormalTok("afex"); package. Because in many instances we work with unbalanced data (i.e.~each group x group combination does not have the same number of participants), we tend to calculate something called #emph[Type III] Sums of Squares/ANOVAs. We won't dive too much into this, but this is essentially about how sums of squares are calculated, and how the effects are tested. Learning Statistics with R has an excellent explanation of what the various types are.

#block[
#Skylighting(([#NormalTok("twoway_alcohol_aov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov_ez");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("data =");#NormalTok(" twoway_alcohol,");],
[#NormalTok("  ");#AttributeTok("id =");#NormalTok(" ");#StringTok("\"ptcpt\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("dv =");#NormalTok(" ");#StringTok("\"spend\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("between =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"alcohol_type\"");#NormalTok(", ");#StringTok("\"genre\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("anova_table =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");#AttributeTok("es =");#NormalTok(" ");#StringTok("\"pes\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("include_aov =");#NormalTok(" ");#ConstantTok("TRUE");],
[#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Converting to factor: alcohol_type, genre");],));
]
#block[
#Skylighting(([#NormalTok("Contrasts set to contr.sum for the following variables: alcohol_type, genre");],));
]
]
The assumptions for a two-way ANOVA are the same as a one-way between groups ANOVA:

- The data should be independent of each other.
- Equality of variance: Just like the one-way ANOVA, we use Levene's test to examine our equality of variance assumption.

#block[
#Skylighting(([#NormalTok("twoway_alcohol ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("levene_test");#NormalTok("(spend ");#SpecialCharTok("~");#NormalTok(" alcohol_type ");#SpecialCharTok("*");#NormalTok(" genre, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 4");],
[#NormalTok("    df1   df2 statistic     p");],
[#NormalTok("  <int> <int>     <dbl> <dbl>");],
[#NormalTok("1     3   196    0.0528 0.984");],));
]
]
- Normality of residuals: Look at the Shapiro-Wilk test (on the residuals) or a Q-Q plot. If you use #NormalTok("aov_ez()"); to calculate your ANOVA, note that the residuals are within either #NormalTok("aov"); or #NormalTok("lm"); within your ANOVA, so you will find them in #NormalTok("model$aov$residuals");:

#block[
#Skylighting(([#CommentTok("# twoway_alcohol_aov <- aov(spend ~ alcohol_type * genre, data = twoway_alcohol)");],
[#FunctionTok("shapiro.test");#NormalTok("(twoway_alcohol_aov");#SpecialCharTok("$");#NormalTok("aov");#SpecialCharTok("$");#NormalTok("residuals)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  twoway_alcohol_aov$aov$residuals");],
[#NormalTok("W = 0.99647, p-value = 0.9295");],));
]
]
Both assumptions appear to be intact.

=== Output
<output-8>
Let's first look at our output for the omnibus ANOVA. The way to read this table is much like the same for a one-way ANOVA, but now we need to read across each line - as each line represents a different effect. So we see that:

- There is no main effect for alcohol (#emph[p] = .137),
- There is a main effect for genre (#emph[p] \< .001),
- Importantly, there is a significant interaction effect for alcohol x genre (#emph[p] \< .001).

#block[
#Skylighting(([#NormalTok("twoway_alcohol_aov");],));
#block[
#Skylighting(([#NormalTok("Anova Table (Type 3 tests)");],
[],
[#NormalTok("Response: spend");],
[#NormalTok("              Effect     df  MSE           F  pes p.value");],
[#NormalTok("1       alcohol_type 1, 196 1.02        2.23 .011    .137");],
[#NormalTok("2              genre 1, 196 1.02 4295.08 *** .956   <.001");],
[#NormalTok("3 alcohol_type:genre 1, 196 1.02  519.96 *** .726   <.001");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '+' 0.1 ' ' 1");],));
]
]
In other words, there is a significant effect of background music genre on how much people spent on alcohol, but this depended on the type of alcohol they bought. Because this interaction is significant, we now need to turn to conducting #strong[simple effects tests] to decompose what is actually going on.

Remember, for a simple effects test we want to test for differences between the levels of one variable, at every level of the other variable. One option is to hold alcohol as a constant, and compare genre for each type of alcohol purchased. Another is to instead hold genre constant and compare the two types of alcohol.

Although it's up to us to determine which set of comparisons we interpret, it's useful to return to our original research question to guide our thinking here. Remember that we were originally interested in the effect of music on alcohol spend, but we thought this might depend on the type of wine being purchased. In that case, we might wish to hold #emph[alcohol] type constant, and compare the two genres against each other.

That means that we need to conduct the following comparisons:

- For #strong[beer], country vs classical
- For #strong[wine], country vs classical

In R, we can simply use #NormalTok("emmeans"); to generate these comparisons.

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(twoway_alcohol_aov, ");#SpecialCharTok("~");#NormalTok(" genre, ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"alcohol_type\"");#NormalTok(") ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(") ");],));
#block[
#Skylighting(([#NormalTok("alcohol_type = beer:");],
[#NormalTok(" contrast            estimate    SE  df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" classical - country     6.11 0.202 196     5.72     6.51  30.242 <0.0001");],
[],
[#NormalTok("alcohol_type = wine:");],
[#NormalTok(" contrast            estimate    SE  df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" classical - country    12.64 0.202 196    12.24    13.04  62.416 <0.0001");],
[],
[#NormalTok("Confidence level used: 0.95 ");],));
]
]
We can see that:

- For beer, people spent more money if classical was on in the background compared to country (Mean difference = 6.11, #emph[t] = 30.24, #emph[p] \< .001).
- But for wine, this difference was even greater - participants spent much more on wine if classical music was playing in the background (MD = 12.64, #emph[t] = 62.42, #emph[p] \< .001).

Of course, it might make more sense to do the simple effects tests the other way round; in other words, hold genre constant and compare how much was spent on each alcohol type. You can still absolutely find out this information by changing the #NormalTok("by"); argument within #NormalTok("emmeans()");:

- For #strong[country], wine vs beer (wine country - beer country): #emph[t] = 15.34, #emph[p] \< .001
- For #strong[classical], wine vs beer (wine classical - beer classical): #emph[t] = 16.85, #emph[p] \< .001.

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(twoway_alcohol_aov, ");#SpecialCharTok("~");#NormalTok(" alcohol_type, ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"genre\"");#NormalTok(") ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(") ");],));
#block[
#Skylighting(([#NormalTok("genre = classical:");],
[#NormalTok(" contrast    estimate    SE  df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" beer - wine    -3.48 0.206 196    -3.88    -3.07 -16.847 <0.0001");],
[],
[#NormalTok("genre = country:");],
[#NormalTok(" contrast    estimate    SE  df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" beer - wine     3.05 0.198 196     2.66     3.44  15.378 <0.0001");],
[],
[#NormalTok("Confidence level used: 0.95 ");],));
]
]
=== Write-up
<write-up>
A two-way ANOVA was conducted to test whether alcohol type and music genre had an effect on spending habits. We found a significant main effect of music genre (#emph[F]\(1, 196) = 4295.08, #emph[p] \< .001) but no significant main effect of alcohol type (#emph[p] = .137). We found a significant two-way interaction between alcohol type and genre (#emph[F]\(1, 196) = 519.97, #emph[p] \< .001). To follow up this two-way interaction, we conducted simple effects tests. The simple effect of genre was analysed for each level of alcohol type with Holm corrections. On average, people spent \$6.11 more on beer if they heard classical music compared to country music (#emph[t]\(196) = 30.242, #emph[p] \< .001). Likewise, on average people spent \$12.64 more on wine if they heard classical music compared to country (#emph[t]\(196) = 62.416, #emph[p] \< .001).

== Two-way repeated measures ANOVA
<two-way-repeated-measures-anova>
=== Introduction
<introduction-1>
Similar to its one-way counterpart, in a two-way ANOVA we assess the effect of two within-subjects variables on a dependent variable.

The following example is completely fictional, and has no real grounding in theory (as far as I'm aware). It's intentionally facetious, but hopefully demonstrates the process of doing a two-way repeated measures ANOVA.

=== Example
<example-3>
If you did this subject in 2023 you would have met Victor and Gloria in the second statistics assignment, who were working with data looking at what predicts high school GPA. They've now moved onto a new project about whether listening to happy or sad music may affect exam performance. To do this, they design a nifty little study. Their research question is: #strong[does music affect exam performance under varying conditions of difficulty?]

They recruit 20 participants and bring them into the lab. This is their procedure:

- Participants come into the lab and do a series of standard maths exams. The maths exams are either easy, medium or hard, and participants are randomly assigned to do either the easy or the hard one first. They are also randomly assigned either happy or sad background music as they do the exam.
- Once they have completed the first exam, they take a 10 minute break and then do another exam that is easy, medium, or hard, and with either happy or soft music in the background.
- This process repeats until they have done all combinations of difficulty and background music.
- Each exam is scored out of 100.

We have two #strong[within-subjects] independent variables here:

+ Difficulty of the exam (3 levels: easy, medium, hard)
+ Background music (2 levels: happy or sad)

Every participant therefore does 6 maths exams: easy-happy, easy-sad, medium-happy, medium-sad, hard-happy and hard-sad. The dependent variable of interest is their exam score. We're interested in whether the difficulty and the music type have an effect on exam performance. Because our two IVs are within-subject variables, we will want to use a #strong[two-way repeated measures ANOVA], or a #strong[difficulty (3) x music (2) repeated measures ANOVA].

#block[
#Skylighting(([#NormalTok("twoway_exam ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"factorial\"");#NormalTok(", ");#StringTok("\"twoway_rmanova_long.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 120 Columns: 4");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (2): difficulty, music");],
[#NormalTok("dbl (2): ptcpt, grade");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
R will generally treat character variables as factors, but will order the factors alphabetically. In our instance, because we have a specific order for the categories that is not alphabetical and we want our graph to reflect this, we will need to tell R what order our levels are. This is simple to do with the #NormalTok("factor()"); function, which will create factors from columns in your data. #NormalTok("factor()"); first needs to know what column you are wanting to create factors in, and then it will want to know the specific order of the factors. The order is set with the #NormalTok("levels"); argument.

We will recode both the difficulty and the music type variables for completion's sake, and there are two ways to go about doing this.

First, you can just use base R functions like so:

#block[
#Skylighting(([#NormalTok("twoway_exam");#SpecialCharTok("$");#NormalTok("music ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(twoway_exam");#SpecialCharTok("$");#NormalTok("music, ");#AttributeTok("levels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"happy\"");#NormalTok(", ");#StringTok("\"sad\"");#NormalTok("))");],));
]
Or you can use #NormalTok("factor()"); within mutate and largely identical syntax:

#block[
#Skylighting(([#NormalTok("twoway_exam ");#OtherTok("<-");#NormalTok(" twoway_exam ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("difficulty =");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(difficulty, ");#AttributeTok("levels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"easy\"");#NormalTok(", ");#StringTok("\"medium\"");#NormalTok(", ");#StringTok("\"hard\"");#NormalTok("))");],
[#NormalTok("  )");],));
]
Let's start with the usual descriptives and graphs:

#box(image("08-factorial-anovas_files/figure-typst/unnamed-chunk-26-1.svg"))

#block[
#Skylighting(([#NormalTok("twoway_exam ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(difficulty, music) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("n =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("mean =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(grade),");],
[#NormalTok("    ");#AttributeTok("sd =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(grade),");],
[#NormalTok("    ");#AttributeTok("se =");#NormalTok(" sd");#SpecialCharTok("/");#FunctionTok("sqrt");#NormalTok("(n)");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 6");],
[#NormalTok("# Groups:   difficulty [3]");],
[#NormalTok("  difficulty music     n  mean    sd    se");],
[#NormalTok("  <fct>      <fct> <int> <dbl> <dbl> <dbl>");],
[#NormalTok("1 easy       happy    20  71.9  6.25  1.40");],
[#NormalTok("2 easy       sad      20  67.5  5.97  1.33");],
[#NormalTok("3 medium     happy    20  50.8  5.18  1.16");],
[#NormalTok("4 medium     sad      20  50.6  4.65  1.04");],
[#NormalTok("5 hard       happy    20  50.5  6.74  1.51");],
[#NormalTok("6 hard       sad      20  38.8  6.67  1.49");],));
]
]
Eyeballing the graph, we can see that there might be some sort of effect happening. Unsurprisingly, it looks like the easy maths exams are, well. easier, because people are scoring better on them. There #emph[might] be an effect of music, because in both easy and hard conditions it looks like people do better with happy music compared to sad music. But the interaction plot tells us there's something clearly going on, and it paints a really interesting story on its own. It appears that there's almost a 'plateau'-ing effect with medium difficulty, in that both happy and sad hit the same point in exam scores. However, it looks like for happy music, harder exams see no further decrease in performance - but there is a sharp drop again for sad music.

=== Assumptions
<assumptions-1>
The assumptions for a two-way RM ANOVA is the same as a one-way RM-ANOVA:

- The data from the conditions should be normally distributed. (More specifically, the residuals should be normally distributed.)

- The data for each subject should be independent of every other subject.

- #strong[Sphericity] must be met.

As is the case with one-way repeated measures ANOVAs, the assumption of sphericity is only tested when there are #emph[three] or more levels; with only two levels, the assumption is always met. The output is below with the main ANOVA output. The sphericity for all of our effects is intact, so we don't have any issues here, but if we did the same principle would apply - we would apply our corrections depending on the value of epsilon.

Let's also see if our variables are normally distributed.

R-Note: For a repeated measures ANOVA, for some reason the closest you can get to generating what Jamovi does is to build an #NormalTok("aov()"); model without an explicit #NormalTok("Error()"); term - as would be the case for a fully between-subjects ANOVA. You can then use the standardised residuals to create a Q-Q plot using the below code. Note that #NormalTok("broom:augment()"); is just a helper function that nicely extracts the residuals:

#Skylighting(([#FunctionTok("aov");#NormalTok("(grade ");#SpecialCharTok("~");#NormalTok(" difficulty ");#SpecialCharTok("*");#NormalTok(" music, ");#AttributeTok("data =");#NormalTok(" twoway_exam) ");#SpecialCharTok("%>%");],
[#NormalTok("  broom");#SpecialCharTok("::");#FunctionTok("augment");#NormalTok("() ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("sample =");#NormalTok(" .std.resid)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_qq");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_qq_line");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("Warning: The `augment()` method for objects of class `aov` is not maintained by the broom team, and is only supported through the `lm` tidier method. Please be cautious in interpreting and reporting broom output.");],
[],
[#NormalTok("This warning is displayed once per session.");],));
]
#box(image("08-factorial-anovas_files/figure-typst/unnamed-chunk-28-1.svg"))

It's not… great but for the purposes of demonstration, we'll run with it anyway.

=== Output
<output-9>
Here's our output from R:

#block[
#Skylighting(([#NormalTok("twoway_exam_aov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov_ez");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("data =");#NormalTok(" twoway_exam,");],
[#NormalTok("  ");#AttributeTok("id =");#NormalTok(" ");#StringTok("\"ptcpt\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("dv =");#NormalTok(" ");#StringTok("\"grade\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("within =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"difficulty\"");#NormalTok(", ");#StringTok("\"music\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("anova_table =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");#AttributeTok("es =");#NormalTok(" ");#StringTok("\"pes\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("include_aov =");#NormalTok(" ");#ConstantTok("TRUE");],
[#NormalTok(")");],
[],
[#NormalTok("twoway_exam_aov");],));
#block[
#Skylighting(([#NormalTok("Anova Table (Type 3 tests)");],
[],
[#NormalTok("Response: grade");],
[#NormalTok("            Effect          df   MSE          F  pes p.value");],
[#NormalTok("1       difficulty 1.79, 33.92 40.38 189.61 *** .909   <.001");],
[#NormalTok("2            music       1, 19 48.16  18.39 *** .492   <.001");],
[#NormalTok("3 difficulty:music 1.65, 31.36 39.89  10.29 *** .351   <.001");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '+' 0.1 ' ' 1");],
[],
[#NormalTok("Sphericity correction method: GG ");],));
]
]
And here is our output for sphericity:

#block[
#Skylighting(([#CommentTok("# To get sphericity output");],
[],
[#FunctionTok("summary");#NormalTok("(twoway_exam_aov)");],));
#block[
#Skylighting(([],
[#NormalTok("Univariate Type III Repeated-Measures ANOVA Assuming Sphericity");],
[],
[#NormalTok("                 Sum Sq num Df Error SS den Df   F value    Pr(>F)    ");],
[#NormalTok("(Intercept)      363220      1   511.30     19 13497.322 < 2.2e-16 ***");],
[#NormalTok("difficulty        13668      2  1369.60     38   189.613 < 2.2e-16 ***");],
[#NormalTok("music               886      1   915.03     19    18.390 0.0003968 ***");],
[#NormalTok("difficulty:music    677      2  1251.07     38    10.286 0.0002691 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[],
[#NormalTok("Mauchly Tests for Sphericity");],
[],
[#NormalTok("                 Test statistic p-value");],
[#NormalTok("difficulty              0.87972 0.31556");],
[#NormalTok("difficulty:music        0.78826 0.11750");],
[],
[],
[#NormalTok("Greenhouse-Geisser and Huynh-Feldt Corrections");],
[#NormalTok(" for Departure from Sphericity");],
[],
[#NormalTok("                  GG eps Pr(>F[GG])    ");],
[#NormalTok("difficulty       0.89263  < 2.2e-16 ***");],
[#NormalTok("difficulty:music 0.82526  0.0007226 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("                    HF eps   Pr(>F[HF])");],
[#NormalTok("difficulty       0.9789636 4.104076e-20");],
[#NormalTok("difficulty:music 0.8936983 4.903345e-04");],));
]
]
Once again this is quite a busy set of outputs! We can see that there is a significant main effect of difficulty (#emph[F]\(2, 38) = 189.61, #emph[p] \< .001), as well as a significant main effect of music type (#emph[F]\(1, 19) = 18.39, #emph[p] \< .001). There is also a significant interaction effect of difficulty and music (#emph[F]\(2, 38) = 10.29, #emph[p] \< .001). We can also see our sphericity output here; neither the difficulty variable (#emph[W] = .880) nor the difficulty x music interaction (#emph[W] = .788) terms show significant violation of sphericity (#emph[p] \> .05). Therefore we have not corrected for anything in our main ANOVA output. Note that because music only has two levels, there is no sphericity test for it.

To decompose this, we'll do our usual simple effects tests - holding one variable constant and running pairwise comparisons with the other. Based on our original research question, it might make sense to hold the music type constant and compare the exams on difficulty. This means we need to look at all of the rows that compare #strong[easy, medium and hard] for the same kind of music. We can absolutely reverse the interpretation of the simple effects, but doing it in this manner is probably more consistent with the nature of the original research question - it lets us see how participants performed across difficulty levels, based on the music they were listening to.

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(twoway_exam_aov, ");#SpecialCharTok("~");#NormalTok(" music, ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"difficulty\"");#NormalTok(") ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("difficulty = easy:");],
[#NormalTok(" contrast    estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" happy - sad      4.4 1.78 19    0.682     8.12   2.477  0.0228");],
[],
[#NormalTok("difficulty = medium:");],
[#NormalTok(" contrast    estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" happy - sad      0.2 1.58 19   -3.097     3.50   0.127  0.9003");],
[],
[#NormalTok("difficulty = hard:");],
[#NormalTok(" contrast    estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" happy - sad     11.7 2.40 19    6.675    16.72   4.873  0.0001");],
[],
[#NormalTok("Confidence level used: 0.95 ");],));
]
]
From this we can see that

- For happy music:
  - Performance on the easy exam was better than the medium exam (MD = 21.1 points, #emph[p] \< .001).
  - There was no significant difference between the medium and hard exams (MD = 0.30 points, #emph[p] = .863).
  - Performance on the easy exams was naturally significantly higher than hard exams (MD = 21.4 points, #emph[p] \< .001).
- For sad music:
  - Performance on the easy exam was again better than the medium exam (MD = 16.9 points, #emph[p] \< .001).
  - Performance on the medium exam was also significantly higher than the hard exam (MD = 11.8 points, #emph[p] \< .001).
  - Performance on the easy exams was naturally significantly higher than hard exams (MD = 28.7 points, #emph[p] \< .001).

This suggests overall that happy music is probably better for completing exams than sad music, particularly when the exams are difficult.

== Two-way mixed ANOVA
<two-way-mixed-anova>
=== Introduction
<introduction-2>
In a mixed factorial design, we want to see the effect of a between groups variable and a within-groups variable on a continuous DV. These are also sometimes called repeated measures ANOVAs (i.e.~repeated measures designs with a between-group variable), but this can be a little confusing; for that reason, calling them a mixed factorial model is preferred.

The data we'll use for this one is of a mock longitudinal randomised-controlled trial. This kind of design is common when testing the effect of an intervention - and that's exactly what we'll do here. This mock dataset is also a bit more complex than the previous ones we've looked at just to give the full range of assumption testing and modelling that we have to do.

=== Example
<example-4>
Elaine and Chaise ran an RCT testing the effect of a music listening intervention on anxiety scores. To do this, participants were randomly allocated to three conditions: a music listening intervention (listen to a podcast for 30 minutes a day), a control exercise intervention (walk for 30 minutes a day) and a control nothing intervention (do nothing). Participants were tested at three timepoints: at the start of the study, at the 6 week mark and then at the 12 week mark. (With thanks to the datarium package for providing a perfect test dataset for this example.)

In other words, we have two variables:

+ Intervention: a between-groups variable, because participants were randomly assigned to one of three interventions (3 levels; Control, Exercise, Music)
+ Timepoint, a within-groups variable as all participants were measured at 3 timepoints (3 levels: 0 weeks, 6 weeks, 12 weeks)

This gives us a two-way, 3 x 3 mixed factorial ANOVA. Let's start by visualising anxiety scores for the three interventions. A boxplot or bar graph is useful here.

#block[
#Skylighting(([#NormalTok("twoway_mixed ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"factorial\"");#NormalTok(", ");#StringTok("\"twoway_mixed.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 135 Columns: 4");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (2): group, time");],
[#NormalTok("dbl (2): id, anxiety");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
#Skylighting(([#CommentTok("# This recodes factors");],
[],
[#NormalTok("twoway_mixed");#SpecialCharTok("$");#NormalTok("group ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(twoway_mixed");#SpecialCharTok("$");#NormalTok("group)");],
[#NormalTok("twoway_mixed");#SpecialCharTok("$");#NormalTok("time ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(twoway_mixed");#SpecialCharTok("$");#NormalTok("time)");],));
]
#box(image("08-factorial-anovas_files/figure-typst/unnamed-chunk-33-1.svg"))

In a mixed ANOVA, we test the effect of both a between-groups and a within-groups variable. This means that the specific assumptions that apply to both between- and within-subject designs now carry over into this design. This means that the following assumptions apply:

- The data should have multivariate normality. Our QQ plot looks a little non-linear, so we might have an issue here.

#Skylighting(([#FunctionTok("aov");#NormalTok("(anxiety ");#SpecialCharTok("~");#NormalTok(" group ");#SpecialCharTok("*");#NormalTok(" time, ");#AttributeTok("data =");#NormalTok(" twoway_mixed) ");#SpecialCharTok("%>%");],
[#NormalTok("  broom");#SpecialCharTok("::");#FunctionTok("augment");#NormalTok("() ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("sample =");#NormalTok(" .std.resid)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_qq");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_qq_line");#NormalTok("()");],));
#box(image("08-factorial-anovas_files/figure-typst/unnamed-chunk-34-1.svg"))

- Homogeneity of variance - the between-subject groups should have the same variance, at each level of the within-subjects variable. None of the tests are significant (p \> .05), so we're ok here. To do this in R, we run Levene's test at each timepoint:

#block[
#Skylighting(([#NormalTok("twoway_mixed ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(time) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("levene_test");#NormalTok("(anxiety ");#SpecialCharTok("~");#NormalTok(" group, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 3 × 5");],
[#NormalTok("  time       df1   df2 statistic     p");],
[#NormalTok("  <fct>    <int> <int>     <dbl> <dbl>");],
[#NormalTok("1 0 weeks      2    42     0.161 0.852");],
[#NormalTok("2 12 weeks     2    42     0.711 0.497");],
[#NormalTok("3 6 weeks      2    42     0.481 0.621");],));
]
]
- Sphericity of the within-subject variable must be met. Our sphericity assumption technically isn't violated (#emph[p] = .079), but this is so close to an arbitrary threshold that we might consider reporting corrected versions anyway. However, we'll forge ahead with our original omnibus model and report that. #NormalTok("aov_ez()"); can give you this in the output below.

=== Output
<output-10>
Below is our main output from R. Unlike Jamovi and some other software, R does not split the output by between- or within-subject factors - which makes reading the output slightly easier. Based on the output, we can see that we have a significant main effect of group (#emph[F]\(2, 42) = 4.352, #emph[p] = .019), and also a significant main effect of time (#emph[F]\(2, 84) = 394.909, #emph[p] \< .001). We also have a significant interaction (#emph[F]\(4, 84) = 110.188, #emph[p] \< .001).

#block[
#Skylighting(([#NormalTok("twoway_mixed_aov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov_ez");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("data =");#NormalTok(" twoway_mixed,");],
[#NormalTok("  ");#AttributeTok("id =");#NormalTok(" ");#StringTok("\"id\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("dv =");#NormalTok(" ");#StringTok("\"anxiety\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("between =");#NormalTok(" ");#StringTok("\"group\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("within =");#NormalTok(" ");#StringTok("\"time\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("anova_table =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");#AttributeTok("es =");#NormalTok(" ");#StringTok("\"pes\"");#NormalTok(")");],
[#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Contrasts set to contr.sum for the following variables: group");],));
]
#Skylighting(([#NormalTok("twoway_mixed_aov");],));
#block[
#Skylighting(([#NormalTok("Anova Table (Type 3 tests)");],
[],
[#NormalTok("Response: anxiety");],
[#NormalTok("      Effect          df  MSE          F  pes p.value");],
[#NormalTok("1      group       2, 42 7.12     4.35 * .172    .019");],
[#NormalTok("2       time 1.79, 75.24 0.09 394.91 *** .904   <.001");],
[#NormalTok("3 group:time 3.58, 75.24 0.09 110.19 *** .840   <.001");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '+' 0.1 ' ' 1");],
[],
[#NormalTok("Sphericity correction method: GG ");],));
]
#Skylighting(([#CommentTok("# To get details on sphericity");],
[],
[#FunctionTok("summary");#NormalTok("(twoway_mixed_aov)");],));
#block[
#Skylighting(([],
[#NormalTok("Univariate Type III Repeated-Measures ANOVA Assuming Sphericity");],
[],
[#NormalTok("            Sum Sq num Df Error SS den Df   F value  Pr(>F)    ");],
[#NormalTok("(Intercept)  34919      1  299.146     42 4902.6660 < 2e-16 ***");],
[#NormalTok("group           62      2  299.146     42    4.3518 0.01916 *  ");],
[#NormalTok("time            67      2    7.081     84  394.9095 < 2e-16 ***");],
[#NormalTok("group:time      37      4    7.081     84  110.1876 < 2e-16 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[],
[#NormalTok("Mauchly Tests for Sphericity");],
[],
[#NormalTok("           Test statistic  p-value");],
[#NormalTok("time              0.88364 0.079193");],
[#NormalTok("group:time        0.88364 0.079193");],
[],
[],
[#NormalTok("Greenhouse-Geisser and Huynh-Feldt Corrections");],
[#NormalTok(" for Departure from Sphericity");],
[],
[#NormalTok("            GG eps Pr(>F[GG])    ");],
[#NormalTok("time       0.89577  < 2.2e-16 ***");],
[#NormalTok("group:time 0.89577  < 2.2e-16 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("              HF eps   Pr(>F[HF])");],
[#NormalTok("time       0.9330916 1.037156e-40");],
[#NormalTok("group:time 0.9330916 1.461019e-30");],));
]
]
Let's decompose this with simple effects. Given the original question, here it might make sense to hold the group constant, and examine how they change over time.

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(twoway_mixed_aov, ");#SpecialCharTok("~");#NormalTok(" time, ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"group\"");#NormalTok(") ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("group = control:");],
[#NormalTok(" contrast             estimate     SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X0.weeks - X12.weeks     0.58 0.1230 42   0.3324    0.828   4.727 <0.0001");],
[#NormalTok(" X0.weeks - X6.weeks      0.16 0.0950 42  -0.0316    0.352   1.685  0.0994");],
[#NormalTok(" X12.weeks - X6.weeks    -0.42 0.0982 42  -0.6182   -0.222  -4.276  0.0001");],
[],
[#NormalTok("group = exercise:");],
[#NormalTok(" contrast             estimate     SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X0.weeks - X12.weeks     1.12 0.1230 42   0.8724    1.368   9.128 <0.0001");],
[#NormalTok(" X0.weeks - X6.weeks      0.18 0.0950 42  -0.0116    0.372   1.896  0.0649");],
[#NormalTok(" X12.weeks - X6.weeks    -0.94 0.0982 42  -1.1382   -0.742  -9.571 <0.0001");],
[],
[#NormalTok("group = music:");],
[#NormalTok(" contrast             estimate     SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X0.weeks - X12.weeks     3.45 0.1230 42   3.2057    3.701  28.144 <0.0001");],
[#NormalTok(" X0.weeks - X6.weeks      2.00 0.0950 42   1.8084    2.192  21.063 <0.0001");],
[#NormalTok(" X12.weeks - X6.weeks    -1.45 0.0982 42  -1.6515   -1.255 -14.797 <0.0001");],
[],
[#NormalTok("Confidence level used: 0.95 ");],));
]
]
Let's bulletpoint the main feature of each, and you can refer to the output below as you go through:

- For controls, anxiety scores were not significantly different between the 0 week and 6 week mark (#emph[p] = .099). However, anxiety scores were significantly lower at 12 weeks compared to 6 weeks (#emph[p] \< .001). Scores were also significantly lower at 12 weeks compared to 0 weeks (#emph[p] \< .001).
- For the exercise group, anxiety scores were not significantly different from 0 weeks to 6 weeks (#emph[p] = .065). However, anxiety scores significantly decreased from 6 weeks to 12 weeks (#emph[p] \< .001). Scores were also significantly lower after 12 weeks than at 0 weeks (#emph[p] \< .001).
- For the music group, anxiety scores significantly decreased between 0 weeks and 6 weeks (#emph[p] \< .001). Scores were significantly lower at the 12 week mark again compared to the 6 week mark (#emph[p] \< .001). Scores were also significantly lower at 12 weeks compared to 0 weeks (#emph[p] \< .001).

Of course, if you were writing these results up in full then you would also want to include means and standard deviations, or other relevant values like the mean difference.

Phew - all done!

== Three-way ANOVA
<three-way-anova>
=== Why not three?
<why-not-three>
In this module we've largely focused on two-way ANOVAs, where we have two independent variables. Why not more than that, you may ask? Is it possible to do a three-way, four-way or even a five-way ANOVA?

The short answer is yes. The longer answer, in my view, is yes - but some caution is warranted. We'll focus on a three-way ANOVA here. In a three-way ANOVA, we test for relationships between three independent variables - A, B and C - on a continuous outcome, just like other ANOVAs. As in the case of the two-way ANOVA, we typically not only test the main effects of the three IVs, but also interactions between all of them. This means that in a standard three-way ANOVA, we end up estimating the following effects:

- Three main effects: variable A, B and C
- Three first-order interactions: AxB, AxC and BxC
- One second-order interaction: AxBxC.

Suddenly we've gone from interpreting 3 effects to 7 - and we saw how much work it was to really work through a two-way interaction as is! The key extension here is that not only do we test for all possible two-way interactions, but our highest-order term is now a #emph[three-way] interaction (ABC). In essence, this would be claiming that the two-way interaction of AB also depends on the level of C.

Naturally, we can extend this thinking to adding more IVs. Let's now take a look at a four-way ANOVA with four variables, A, B, C and D:

- Four main effects (A, B, C, D)
- Six first-order interactions: AxB, AxC, AxD, BxC, BxD, CxD
- Three second-order interactions: AxBxC, AxCxD, BxCxD
- One third-order interaction: ABCD

This is 14 effects!! Hence why some caution is potentially required - by definition (i.e.~the principle of marginality), if we are modelling four-way interactions we are not only modelling the four-way ABCD interaction but everything else underneath it. This can make interpretation really thorny, and so you really have to be comfortable with interpreting the effect!

It's worth stressing here that there is no real requirement to actually model interaction effects per se. #emph[If] you have a good reason to not include them, you can actually do three-way ANOVAs #emph[without] higher-order interactions. The thing you #emph[can't] do is model higher-order interactions without everything underneath them.

Nevertheless, three-way ANOVAs (and even beyond that) are not necessarily uncommon, so it doesn't hurt to know about them. We will work through an example in full here.

=== Example
<example-5>
This dataset is from a fictional experiment looking at how gender (male and female), risk of migraine (low or high) and different treatments (labelled X, Y and Z) impacted pain scores associated with a migraine headache. This dataset is a lightly adapted version of the #NormalTok("headache"); dataset from the #NormalTok("datarium"); package.

This gives us a gender (2) x risk (2) x treatment (3) three-way design. Below is a snippet of what our data looks like:

#block[
#Skylighting(([#NormalTok("headache ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"factorial\"");#NormalTok(", ");#StringTok("\"threeway_headache.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 72 Columns: 5");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (3): gender, risk, treatment");],
[#NormalTok("dbl (2): id, pain_score");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
We want to run a gender (2) x risk (2) x treatment (3) three-way ANOVA to see whether these predictors have an effect on overall pain scores.

Let's start by visualising this data. We cannot fully visualise a three-way interaction because we inherently need four dimensions (as we have three predictors and one outcome variable). The best way to approach this is to draw a series of two-way interaction plots, split by the third variable. In the example below, the graphs show treatment on the x-axis, pain scores on the y-axis, different lines for low and high risk and separate graphs for male and female participants:

#box(image("08-factorial-anovas_files/figure-typst/unnamed-chunk-39-1.svg"))

=== Assumptions and output
<assumptions-and-output>
Let's run our main ANOVA. In R, we can simply use the #NormalTok("aov_ez()"); function here again to build our ANOVA model:

#block[
#Skylighting(([#NormalTok("threeway_aov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov_ez");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("data =");#NormalTok(" headache,");],
[#NormalTok("  ");#AttributeTok("id =");#NormalTok(" ");#StringTok("\"id\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("dv =");#NormalTok(" ");#StringTok("\"pain_score\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("between =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"gender\"");#NormalTok(", ");#StringTok("\"risk\"");#NormalTok(", ");#StringTok("\"treatment\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("anova_table =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");#AttributeTok("es =");#NormalTok(" ");#StringTok("\"pes\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("include_aov =");#NormalTok(" ");#ConstantTok("TRUE");],
[#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Converting to factor: gender, risk, treatment");],));
]
#block[
#Skylighting(([#NormalTok("Contrasts set to contr.sum for the following variables: gender, risk, treatment");],));
]
]
Our assumptions are exactly the same as before - we test for normality of residuals and equality/homogeneity of variance. The tests are exactly the same. Based on Levene's test and the Shapiro-Wilks test, we have no violations in multivariate equality of variance (#emph[p] = .994) or normality (#emph[p] = .398).

#block[
#Skylighting(([#CommentTok("# Levene's test");],
[#NormalTok("headache ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("levene_test");#NormalTok("(pain_score ");#SpecialCharTok("~");#NormalTok(" gender ");#SpecialCharTok("*");#NormalTok(" risk ");#SpecialCharTok("*");#NormalTok(" treatment, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 4");],
[#NormalTok("    df1   df2 statistic     p");],
[#NormalTok("  <int> <int>     <dbl> <dbl>");],
[#NormalTok("1    11    60     0.237 0.994");],));
]
]
#block[
#Skylighting(([#CommentTok("# Normality ");],
[#FunctionTok("shapiro.test");#NormalTok("(threeway_aov");#SpecialCharTok("$");#NormalTok("aov");#SpecialCharTok("$");#NormalTok("residuals)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  threeway_aov$aov$residuals");],
[#NormalTok("W = 0.98212, p-value = 0.3981");],));
]
]
Now let's examine our omnibus ANOVA output.

#block[
#Skylighting(([#NormalTok("threeway_aov");],));
#block[
#Skylighting(([#NormalTok("Anova Table (Type 3 tests)");],
[],
[#NormalTok("Response: pain_score");],
[#NormalTok("                 Effect    df   MSE         F  pes p.value");],
[#NormalTok("1                gender 1, 60 19.35 16.20 *** .213   <.001");],
[#NormalTok("2                  risk 1, 60 19.35 92.70 *** .607   <.001");],
[#NormalTok("3             treatment 2, 60 19.35   7.32 ** .196    .001");],
[#NormalTok("4           gender:risk 1, 60 19.35      0.14 .002    .708");],
[#NormalTok("5      gender:treatment 2, 60 19.35    3.34 * .100    .042");],
[#NormalTok("6        risk:treatment 2, 60 19.35      0.71 .023    .494");],
[#NormalTok("7 gender:risk:treatment 2, 60 19.35   7.41 ** .198    .001");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '+' 0.1 ' ' 1");],));
]
]
What do our results tell us? Well:

- We have significant main effects of gender (#emph[F]\(1, 60) = 16.20, #emph[p] \< .001), risk group (#emph[F]\(1, 60) = 92.69, #emph[p] \< .001) and treatment (#emph[F]\(2, 60) = 7.32, #emph[p] = .001).

- We have a significant two-way gender x treatment interaction (#emph[F]\(2, 60) = 3.34, #emph[p] = .042), but no significant interactions between gender x risk (#emph[p] = .708) and risk x treatment (#emph[p] = .494).

- Our highest-order interaction, gender x risk x treatment is significant (#emph[F]\(2, 60) = 7.41, #emph[p] = .001).

=== Breaking down complex interactions
<breaking-down-complex-interactions>
Great, so we know that we're dealing with a significant three-way interaction. But… how do we break that down?

For a two-way ANOVA, this was easy - recall that we conducted #strong[simple effects tests], where we interpreted the effect of variable A at each level of variable B (or vice versa). In essence, we ran comparisons on the main effects for each level of the other variable.

We now need to extend that that thinking to the number of effects in a full three-way ANOVA. Naturally, as we saw with two-way ANOVAs, if we have a significant #emph[three-way] interaction we have to break down the lower-order terms to unpack this interaction. This includes both main effects and two-way interactions, giving rise to simple #strong[main] effects and simple #strong[interaction] effects.

As we are primarily interested in the efficacy of the treatment on headacoe pain, it might make sense for us to examine the risk x treatment interaction for each gender. We do so by essentially running two-way ANOVAs between A and B (in this case, risk and treatment) at each level of C (in this case, gender). Let's put this in a plot form, with 95% CIs:

#box(image("08-factorial-anovas_files/figure-typst/unnamed-chunk-44-1.svg"))

Here, we can see something interesting going on. For both men and women, the efficacy of the treatments might differ - but this may also depend on their risk. For women, for instance, there may not be much change in headache pain, especially for women at high risk of headaches - we can see that the 95% CIs in this group all largely overlap with each other. For men at high risk though, there appears to be a decent difference between treatments X and Y. This is what we will drill down into further.

To do so, we first use #NormalTok("emmeans()"); to calculate our estimated marginal means for our three-way interactions. For ease, this will be assigned to a variable called #NormalTok("headache_emm"); like below:

#block[
#Skylighting(([#NormalTok("headache_emm ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("emmeans");#NormalTok("(threeway_aov, ");#SpecialCharTok("~");#NormalTok(" treatment ");#SpecialCharTok("*");#NormalTok(" gender ");#SpecialCharTok("*");#NormalTok(" risk)");],
[#NormalTok("headache_emm");],));
#block[
#Skylighting(([#NormalTok(" treatment gender risk emmean  SE df lower.CL upper.CL");],
[#NormalTok(" X         female high   78.9 1.8 60     75.3     82.5");],
[#NormalTok(" Y         female high   81.2 1.8 60     77.6     84.8");],
[#NormalTok(" Z         female high   81.0 1.8 60     77.4     84.6");],
[#NormalTok(" X         male   high   92.7 1.8 60     89.1     96.3");],
[#NormalTok(" Y         male   high   82.3 1.8 60     78.7     85.9");],
[#NormalTok(" Z         male   high   79.7 1.8 60     76.1     83.3");],
[#NormalTok(" X         female low    74.2 1.8 60     70.6     77.7");],
[#NormalTok(" Y         female low    68.4 1.8 60     64.8     72.0");],
[#NormalTok(" Z         female low    69.8 1.8 60     66.2     73.4");],
[#NormalTok(" X         male   low    76.1 1.8 60     72.5     79.6");],
[#NormalTok(" Y         male   low    73.1 1.8 60     69.5     76.7");],
[#NormalTok(" Z         male   low    74.5 1.8 60     70.9     78.0");],
[],
[#NormalTok("Confidence level used: 0.95 ");],));
]
]
To calculate the initial two-way simple interactions, we can use the #NormalTok("joint_tests()"); function from #NormalTok("emmeans");, which will calculate ANOVAs based on the contrasts we specify. In this case, because we want to calculate two-way interactions for each level of gender, we specify the argument #NormalTok("by = \"gender\"");.

#block[
#Skylighting(([#NormalTok("headache_emm ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("joint_tests");#NormalTok("(");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"gender\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("gender = female:");],
[#NormalTok(" model term     df1 df2 F.ratio p.value");],
[#NormalTok(" treatment        2  60   0.482  0.6201");],
[#NormalTok(" risk             1  60  42.803 <0.0001");],
[#NormalTok(" treatment:risk   2  60   2.868  0.0646");],
[],
[#NormalTok("gender = male:");],
[#NormalTok(" model term     df1 df2 F.ratio p.value");],
[#NormalTok(" treatment        2  60  10.174  0.0002");],
[#NormalTok(" risk             1  60  50.037 <0.0001");],
[#NormalTok(" treatment:risk   2  60   5.252  0.0079");],));
]
]
Focusing on the two-way interactions for each gender here, we see that the interaction is significant for males (#emph[p] = .008) but not for females (#emph[p] = .065).

Now we can break down these two-way interactions further to examine the simple main effects of interest (alternatively called simple #emph[simple] effects). As above, since we might be most interested in the differences between treatments, let's examine the simple main effects of treatment.

To do that, we can use the #NormalTok("pairs()"); function as we always have. As a bit of a shortcut to obtain the simple effects we are interested in, we can specify the argument #NormalTok("simple = \"treatment\""); to indicate that we want simple effects for this variable. This is equivalent to #NormalTok("pairs(by = c(\"gender\", \"risk\"))");.

#block[
#Skylighting(([#NormalTok("headache_emm ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(", ");#AttributeTok("simple =");#NormalTok(" ");#StringTok("\"treatment\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("gender = female, risk = high:");],
[#NormalTok(" contrast estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X - Y       -2.31 2.54 60   -7.390     2.77  -0.910  0.3666");],
[#NormalTok(" X - Z       -2.17 2.54 60   -7.250     2.91  -0.855  0.3962");],
[#NormalTok(" Y - Z        0.14 2.54 60   -4.940     5.22   0.055  0.9562");],
[],
[#NormalTok("gender = male, risk = high:");],
[#NormalTok(" contrast estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X - Y       10.40 2.54 60    5.317    15.48   4.094  0.0001");],
[#NormalTok(" X - Z       13.06 2.54 60    7.978    18.14   5.142 <0.0001");],
[#NormalTok(" Y - Z        2.66 2.54 60   -2.419     7.74   1.048  0.2990");],
[],
[#NormalTok("gender = female, risk = low:");],
[#NormalTok(" contrast estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X - Y        5.79 2.54 60    0.714    10.87   2.282  0.0261");],
[#NormalTok(" X - Z        4.38 2.54 60   -0.703     9.46   1.723  0.0900");],
[#NormalTok(" Y - Z       -1.42 2.54 60   -6.498     3.66  -0.558  0.5788");],
[],
[#NormalTok("gender = male, risk = low:");],
[#NormalTok(" contrast estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X - Y        2.91 2.54 60   -2.167     7.99   1.147  0.2559");],
[#NormalTok(" X - Z        1.60 2.54 60   -3.484     6.68   0.628  0.5321");],
[#NormalTok(" Y - Z       -1.32 2.54 60   -6.397     3.76  -0.519  0.6059");],
[],
[#NormalTok("Confidence level used: 0.95 ");],));
]
]
What do we see? Let's take this by each combination of gender and risk:

- For women at high risk of headaches, there are no significant differences in efficacy between the treatments (all #emph[p]s \> .05).
- For men at high risk, treatment Y is significantly better than treatment X (#emph[p] \< .001), and treatment X is also significantly better than treatment X (#emph[p] \< .001). However, there is no significant diffrence between treatments Y and Z (#emph[p] = .299).
- For women at low risk, treatment Y is again significantly better than treatment X (#emph[p] = .026). However, no other comparisons are significant (#emph[p]s \> .05).
- For men at low risk, there are no significant differences in efficacy between the treatments (all #emph[p]s \> .05).

Of course, with this many comparisons you may wish to correct for multiple comparisons - particularly if these simple effects are being conducted post-hoc, and not based on the question. Here is an example with Holm corrections:

#block[
#Skylighting(([#NormalTok("headache_emm ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("(");#AttributeTok("infer =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("adjust =");#NormalTok(" ");#StringTok("\"holm\"");#NormalTok(", ");#AttributeTok("simple =");#NormalTok(" ");#StringTok("\"treatment\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("gender = female, risk = high:");],
[#NormalTok(" contrast estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X - Y       -2.31 2.54 60   -8.565     3.94  -0.910  1.0000");],
[#NormalTok(" X - Z       -2.17 2.54 60   -8.425     4.08  -0.855  1.0000");],
[#NormalTok(" Y - Z        0.14 2.54 60   -6.115     6.39   0.055  1.0000");],
[],
[#NormalTok("gender = male, risk = high:");],
[#NormalTok(" contrast estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X - Y       10.40 2.54 60    4.142    16.65   4.094  0.0003");],
[#NormalTok(" X - Z       13.06 2.54 60    6.803    19.31   5.142 <0.0001");],
[#NormalTok(" Y - Z        2.66 2.54 60   -3.594     8.92   1.048  0.2990");],
[],
[#NormalTok("gender = female, risk = low:");],
[#NormalTok(" contrast estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X - Y        5.79 2.54 60   -0.461    12.05   2.282  0.0782");],
[#NormalTok(" X - Z        4.38 2.54 60   -1.878    10.63   1.723  0.1799");],
[#NormalTok(" Y - Z       -1.42 2.54 60   -7.672     4.84  -0.558  0.5788");],
[],
[#NormalTok("gender = male, risk = low:");],
[#NormalTok(" contrast estimate   SE df lower.CL upper.CL t.ratio p.value");],
[#NormalTok(" X - Y        2.91 2.54 60   -3.342     9.17   1.147  0.7677");],
[#NormalTok(" X - Z        1.60 2.54 60   -4.659     7.85   0.628  1.0000");],
[#NormalTok(" Y - Z       -1.32 2.54 60   -7.572     4.94  -0.519  1.0000");],
[],
[#NormalTok("Confidence level used: 0.95 ");],
[#NormalTok("Conf-level adjustment: bonferroni method for 3 estimates ");],
[#NormalTok("P value adjustment: holm method for 3 tests ");],));
]
]
=== A note about splitting data
<a-note-about-splitting-data>
In SPSS (and likely Jamovi), to conduct simple interaction tests you would typically need to split the data by one of the variables. In our example, we would literally conduct two-way ANOVAs for males and females separately, which would split our sample size in half. However, an important note is that #NormalTok("emmmeans"); uses the error terms across the #emph[whole] model to calculate test statistics properly.

There does not seem to be a fully consistent approach a to which way is better, and this might potentially be a limitation of software more so than methodological approaches. However, given that these differences will also impact significance it is good to know here. (The same applies for two-way ANOVAs, but all programs handle these well.)

On a related note, it is possible to calculate the two-way simple interactions using #NormalTok("anova_test()"); with the correct model error term. This function has a specific argument called #NormalTok("error");, which specifies which model (in #NormalTok("lm"); form) should be used for calculating error terms. In this instance, because we want the error term from the whole three-way ANOVA model, we extract the #NormalTok("lm"); object from our #NormalTok("aov"); object and pass this to this argument.

#block[
#Skylighting(([#NormalTok("headache ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(gender) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("anova_test");#NormalTok("(pain_score ");#SpecialCharTok("~");#NormalTok(" treatment ");#SpecialCharTok("*");#NormalTok(" risk, ");#AttributeTok("type =");#NormalTok(" ");#DecValTok("3");#NormalTok(", ");#AttributeTok("error =");#NormalTok(" threeway_aov");#SpecialCharTok("$");#NormalTok("lm)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 8");],
[#NormalTok("  gender Effect           DFn   DFd      F             p `p<.05`   ges");],
[#NormalTok("* <chr>  <chr>          <dbl> <dbl>  <dbl>         <dbl> <chr>   <dbl>");],
[#NormalTok("1 female treatment          2    60  0.482 0.62          \"\"      0.016");],
[#NormalTok("2 female risk               1    60 42.8   0.000000015   \"*\"     0.416");],
[#NormalTok("3 female treatment:risk     2    60  2.87  0.065         \"\"      0.087");],
[#NormalTok("4 male   treatment          2    60 10.2   0.000157      \"*\"     0.253");],
[#NormalTok("5 male   risk               1    60 50.0   0.00000000187 \"*\"     0.455");],
[#NormalTok("6 male   treatment:risk     2    60  5.25  0.008         \"*\"     0.149");],));
]
]
== Planned comparisons
<planned-comparisons>
=== Introduction
<introduction-3>
Up until now, the typical process for testing an ANOVA has been something like this:

- Determine null and alternative hypotheses
- Run an omnibus ANOVA
- Run post-hocs to unpack any significant effects

The last point here is of interest to us. Recall that the omnibus ANOVA generally tells us that there is a difference between the means somewhere in our potential list of comparisons. We don't know where that difference may be ahead of time. Post-hoc tests like Tukey tests allow us to 'unpack' these significant differences further. However, post-hocs by definition are #emph[a-posteriori] - they are only done after a significant result/test, meaning that they are strictly #strong[exploratory].

Sometimes, however, we may actually have #emph[a-priori] (i.e.~before the test) hypotheses about specific comparisons we want to make. Often, these are specific predictions based on literature that we want to test in our own data. In these instances, we now move into the possibility of doing planned comparisons.

=== Planned comparisons
<planned-comparisons-1>
As mentioned above, we use #strong[planned comparisons] when we have #strong[specific hypotheses] we want to test. For instance, you may want to compare two specific groups out of four for a hypothetical reason. Or, alternatively, you may wish to compare one group against all of the others at once. These kinds of scenarios can be vital for testing specific hypotheses.

The benefit of planned comparisons is twofold. Firstly, good planned comparisons should be based in either existing theory or on specific hypotheses, meaning that you are generally aiming to test a specific effect for (hopefully) a scientifically sound reason. Secondly, planned comparisons reduce the number of comparisons that need to be made, thereby reducing the overall family-wise Type I error rate. In essence, we only conduct the tests required to evaluate our original research question(s).

=== Linear contrasts
<linear-contrasts>
In planned comparisons, we typically compare two specific means with each other. With that in mind, it may be tempting to simply default to running a t-test or something similar to compare just the two groups you want. However, this would not properly test the planned comparison, because in some instances we must average over the other groups in the comparisons. To correctly set up planned comparisons, we must set up #strong[linear contrasts]. In essence, these allow to specify how the various groups in an ANOVA should be compared.

Here's an intuitive way of thinking about these contrasts. Imagine we want to compare one superstar soccer player (e.g.~maybe Messi) to a given football team of 15. To make the comparison fair, we would #emph[weight] each person in the team of 15 (i.e.~make each person's average worth 1/15), in order for the team's average to be comparable to the superstar player.

In essence, this is what we do when defining linear contrasts, and we do this via defining a contrast matrix. This #strong[contrast matrix] is a way that lets us weight the categories in a variable to create contrasts. While there are several forms of standard contrasts (which is slightly beyond the scope, but #link("https://stats.oarc.ucla.edu/r/library/r-library-contrast-coding-systems-for-categorical-variables/")[here is a good overview].

We assign a positive or negative number to each level in a variable in order to define a contrast. Here, the direction (positive vs negative) matters; any value with a positive contrast coefficient will be on one side of the comparison, and any value with a negative coefficient will be on the other side of the comparison. The linear contrasts #strong[must sum to] zero, meaning that the total on each side must be the same.

Below are three examples of specific contrasts, and their coefficients:

#table(
  columns: 4,
  align: (left,left,left,left,),
  table.header([a], [b], [c], [d],),
  table.hline(),
  [], [Group A], [Group B], [Group C],
  [Group A - Group B], [1], [-1], [0],
  [Group B - Group C], [0], [1], [-1],
  [Group A - (Group B and C)], [2], [-1], [-1],
)
It doesn't really matter what numbers you use to enter these contrasts, so long as they sum to zero. For example, we could also write the first contrast using 0.5 and -0.5 in place of the 1s.

=== An example
<an-example-1>
Let's revisit the one-way ANOVA we ran in 9.5 One way ANOVA:

#quote(block: true)[
Below is another simple example, comparing taste ratings across three different types of slices: caramel slices, vanilla slices and lemon slices. Participants were randomly allocated to taste one of the three slices blindfolded, and were then asked to verbally rate its taste on a scale from 1-10 (10 being super tasty).
]

Now, pretend that this time we have a specific hypothesis we want to test. Namely, pretend that we are only interested in two comparisons:

+ Vanilla - caramel slices
+ Vanilla - caramel and lemon slices

Here's the original ANOVA output for your reference, though we don't need to do anything with this:

#block[
#block[
#Skylighting(([#NormalTok("            Df Sum Sq Mean Sq F value  Pr(>F)   ");],
[#NormalTok("group        2  22.22  11.111   6.897 0.00201 **");],
[#NormalTok("Residuals   60  96.67   1.611                   ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
]
We need to define the contrast coefficients for our two planned contrasts. In R, there are two ways you can do this: either define contrasts at the #emph[aov] level, or use #NormalTok("emmeans");. We will do the latter.

#table(
  columns: 4,
  align: (left,left,left,left,),
  table.header([a], [b], [c], [d],),
  table.hline(),
  [], [Caramel], [Lemon], [Vanilla],
  [Caramel - Vanilla], [1], [0], [-1],
  [Vanilla - (Caramel and Lemon)], [-1], [-1], [2],
)
To set up the contrasts, we first need to know the exact order of our group variable/

#block[
#Skylighting(([#CommentTok("# IDentify levels");],
[],
[#FunctionTok("levels");#NormalTok("(w9_slices");#SpecialCharTok("$");#NormalTok("group)");],));
#block[
#Skylighting(([#NormalTok("[1] \"caramel\" \"lemon\"   \"vanilla\"");],));
]
]
Once we know that, we need to create new variables that will contain the contrasts. To do this, we will create a vector of length #emph[k], where #emph[k] is the total number of groups in the independent/categorical variable. In this case, becasue we have three slice flavours, we need to create vectors of length 3.

The value of each vector item corresponds to the level of the factor. For #NormalTok("emmeans");, all we need to do is use a 1 for the group of interest, and 0 of others; #NormalTok("emmeans"); will build the correct contrast coefficients later depending on what we give it.

#block[
#Skylighting(([#CommentTok("# Define contrasts");],
[],
[#NormalTok("lemon ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("0");#NormalTok(")");],
[#NormalTok("caramel ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("1");#NormalTok(", ");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok(")");],
[#NormalTok("vanilla ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(")");],));
]
Finally, we can perform our contrasts. We start with the same call to #NormalTok("emmeans()");, so we must first give it our aov\`/ANOVA object and indicate our grouping variable.

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(w9_slices_aov, ");#SpecialCharTok("~");#NormalTok(" group) ");],));
#block[
#Skylighting(([#NormalTok(" group   emmean    SE df lower.CL upper.CL");],
[#NormalTok(" caramel   5.62 0.277 60     5.06     6.17");],
[#NormalTok(" lemon     5.14 0.277 60     4.59     5.70");],
[#NormalTok(" vanilla   6.57 0.277 60     6.02     7.13");],
[],
[#NormalTok("Confidence level used: 0.95 ");],));
]
]
Next, we use the #NormalTok("contrast()"); function to perform the pairwise comparisons. (#NormalTok("pairs()");, which we saw earlier, is just a shorthand form of #NormalTok("contrast()");.) Here is where we give the function the speicifc contrasts that we want to run. We do this by supplying the #NormalTok("methods"); argument in #NormalTok("contrast()");. This argument takes a #strong[list] of comparisons we want to run, expressed in #NormalTok("A - B"); form (where A and B are the variables of #emph[contrast coefficients] representing the groups we want to compare).

For example, if we want to compare our caramel and vanilla slices, we simply need to give #NormalTok("caramel - vanilla"); - both of which we defined just above - to a list in #NormalTok("contrast()");. This will generate the following set of output.

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(w9_slices_aov, ");#SpecialCharTok("~");#NormalTok(" group) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("contrast");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("method =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");],
[#NormalTok("      caramel ");#SpecialCharTok("-");#NormalTok(" vanilla");],
[#NormalTok("    )");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok(" contrast    estimate    SE df t.ratio p.value");],
[#NormalTok(" c(1, 0, -1)   -0.952 0.392 60  -2.431  0.0180");],));
]
]
The output is a little hard to read through, but we can fix that by assigning a name to the list item:

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(w9_slices_aov, ");#SpecialCharTok("~");#NormalTok(" group) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("contrast");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("method =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");],
[#NormalTok("      ");#StringTok("\"Caramel - vanilla\"");#NormalTok(" ");#OtherTok("=");#NormalTok(" caramel ");#SpecialCharTok("-");#NormalTok(" vanilla");],
[#NormalTok("    )");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok(" contrast          estimate    SE df t.ratio p.value");],
[#NormalTok(" Caramel - vanilla   -0.952 0.392 60  -2.431  0.0180");],));
]
]
Unlike Jamovi and gamlj, which can only display one given comparison at a time, #NormalTok("emmeans()"); can display multiple. Here, for example, is how we would define our second contrast - that is, vanilla vs the other two slices:

#Skylighting(([#NormalTok("list(\"Vanilla vs others\" = vanilla - (caramel + lemon)/2");],));
Note here that we take the average of 'caramel' and 'lemon', by adding them up and dividing by 2. This will have the same effect of making their contrast coefficients half the weight of the vanilla level (i.e.~it does the maths of calculating the correct contrast coefficient so that it sums to zero).

Instead of making this a whole new #NormalTok("emmeans()"); call, we can simply add that list term to the #NormalTok("list()"); part of our code in the main call.

#block[
#Skylighting(([#FunctionTok("emmeans");#NormalTok("(w9_slices_aov, ");#SpecialCharTok("~");#NormalTok(" group) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("contrast");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("method =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");],
[#NormalTok("      ");#StringTok("\"Caramel - vanilla\"");#NormalTok(" ");#OtherTok("=");#NormalTok(" caramel ");#SpecialCharTok("-");#NormalTok(" vanilla,");],
[#NormalTok("      ");#StringTok("\"Vanilla - others\"");#NormalTok(" ");#OtherTok("=");#NormalTok(" vanilla ");#SpecialCharTok("-");#NormalTok(" (lemon ");#SpecialCharTok("+");#NormalTok(" caramel)");#SpecialCharTok("/");#DecValTok("2");],
[#NormalTok("    )");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok(" contrast          estimate    SE df t.ratio p.value");],
[#NormalTok(" Caramel - vanilla   -0.952 0.392 60  -2.431  0.0180");],
[#NormalTok(" Vanilla - others     1.190 0.339 60   3.509  0.0009");],));
]
]
Using this output, we can see that the comparison between caramel slices and vanilla slices is significant (#emph[t] = 2.43, #emph[p] = .018). Likewise, the comparison between the vanilla slices and the other slices is significant (#emph[t] = 3.51, #emph[p] \< .001).

= Regression continued
<regression-continued>
This section deals with some more advanced topics in ANOVAs and regression. It serves as a continuation to the first chapter on regression, and in particular focuses on multiple regressions. This chapter will cover the following:

- ANCOVA
- Hierarchical regressions
- Model selection
- Identifying and handling outliers

This module won't cover continuous interactions because they are often considered under the topic of moderation - for which there will be a separate module.

Recall that the basic multiple regression looks something like this:

$ y = beta_0 + beta_1 x_1 + beta_2 x_2 + epsilon.alt_i $ As a reminder, the coefficients in this formula correspond to the following:

- $beta_1$ is the coefficient for predictor $x_1$\; i.e.~as $x_1$ increases by 1 unit, $hat(y)$ (the predicted y value) increases by $beta_1$ units, #emph[assuming] $x_2$ does not change
- $beta_2$ is the coefficient for predictor $x_2$, and describes how $hat(y)$ changes assuming $x_1$ does not change
- $epsilon.alt_i$ is the error term, which we assume is normally distributed

We can expand this formula out to include $n$ predictors, as follows:

$ y = beta_0 + beta_1 x_1 + beta_2 x_2 + . . . beta_n x_n + epsilon.alt_i $

== ANCOVAs
<ancovas>
=== Introduction
<introduction-4>
ANCOVA stands for Analysis of #strong[Co-]variance. Its basic definition is that it is an ANOVA, but with the inclusion of a covariate (or a variable we need to control for). The basic idea is that we are performing an ANOVA between our predictors and outcomes after adjusting our predictors (our model) by another variable.

Just like the ANOVA, ANCOVA is a fairly generic term that can refer to a multitude of analyses. In this book we'll stick with ANOVAs relating to between-subjects predictors only.

=== Example
<example-6>
The following data comes from Plaster (1989). The dataset is described as below:

#quote(block: true)[
Male participants were shown a picture of one of three young women. Pilot work had indicated that the one woman was beautiful, another of average physical attractiveness, and the third unattractive. Participants rated the woman they saw on each of twelve attributes. These measures were used to check on the manipulation by the photo. Then the participants were told that the person in the photo had committed a Crime, and asked to rate the seriousness of the crime and recommend a prison sentence, in Years.
]

Our main questions are:

+ Does the perceived attractiveness of the "defendant" (the women in the photo) influence the number of years the mock juror (the participant) sentence them for?
+ How does this relationship change after controlling for the perceived seriousness of the crime?

Our dataset, #NormalTok("jury_data");, contains the following variables:

- Attr: The perceived attractiveness of the defendant (Beautiful, Average, Unattractive)
- Crime: The crime that was commited by the defendant (Burglary, Swindle)
- Serious: The perceived seriousness of the crime from 1-10
- Years: The number of years the participant sentenced the defendant for

=== One-way ANCOVA
<one-way-ancova>
To start us off, let's begin with a simple one-way ANOVA between attractiveness and years. We can see this below.

#block[
#Skylighting(([#NormalTok("jury_data ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"regression_2\"");#NormalTok(", ");#StringTok("\"anova_mockjury.csv\"");#NormalTok("))");],));
]
#block[
#Skylighting(([#NormalTok("jury_aov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov");#NormalTok("(Years ");#SpecialCharTok("~");#NormalTok(" Attr, ");#AttributeTok("data =");#NormalTok(" jury_data)");],
[#FunctionTok("summary");#NormalTok("(jury_aov)");],));
#block[
#Skylighting(([#NormalTok("             Df Sum Sq Mean Sq F value Pr(>F)  ");],
[#NormalTok("Attr          2   70.9   35.47    2.77  0.067 .");],
[#NormalTok("Residuals   111 1421.3   12.80                 ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
#Skylighting(([#FunctionTok("eta_squared");#NormalTok("(jury_aov, ");#AttributeTok("alternative =");#NormalTok(" ");#StringTok("\"two.sided\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("For one-way between subjects designs, partial eta squared is equivalent");],
[#NormalTok("  to eta squared. Returning eta squared.");],));
]
#block[
#Skylighting(([#NormalTok("# Effect Size for ANOVA");],
[],
[#NormalTok("Parameter | Eta2 |       95% CI");],
[#NormalTok("-------------------------------");],
[#NormalTok("Attr      | 0.05 | [0.00, 0.14]");],));
]
]
From this we can infer that the effect of attractiveness is not significant (#emph[F]\(2, 111) = 2.77, #emph[p] = .067, $eta^2$ = .05, 95% CI = \[0, .14\]). In other words, perceived attractiveness does not appear to relate to the years of sentencing.

Let's now add the covariate #NormalTok("Serious"); in. To do this in R, we simply add in the predictor to the #NormalTok("aov"); model just like we would with adding a second predictor in a multiple regression - by specifying #NormalTok("IV + covariate"); within the relevant function. See below for two ways of running an ANCOVA:

#block[
#Skylighting(([#CommentTok("# One way using car::Anova - this is useful for getting the correct eta squared confidence intervals");],
[],
[#FunctionTok("options");#NormalTok("(");#AttributeTok("contrasts =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"contr.helmert\"");#NormalTok(", ");#StringTok("\"contr.poly\"");#NormalTok("))");],
[],
[#NormalTok("jury_acov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov");#NormalTok("(Years ");#SpecialCharTok("~");#NormalTok(" Attr ");#SpecialCharTok("+");#NormalTok(" Serious, ");#AttributeTok("data =");#NormalTok(" jury_data)");],
[#NormalTok("jury_acov_sum ");#OtherTok("<-");#NormalTok(" car");#SpecialCharTok("::");#FunctionTok("Anova");#NormalTok("(jury_acov, ");#AttributeTok("type =");#NormalTok(" ");#DecValTok("3");#NormalTok(")");],
[#NormalTok("jury_acov_sum");],));
#block[
#Skylighting(([#NormalTok("Anova Table (Type III tests)");],
[],
[#NormalTok("Response: Years");],
[#NormalTok("             Sum Sq  Df F value    Pr(>F)    ");],
[#NormalTok("(Intercept)    4.56   1  0.4819   0.48902    ");],
[#NormalTok("Attr          73.26   2  3.8735   0.02368 *  ");],
[#NormalTok("Serious      381.15   1 40.3068 4.998e-09 ***");],
[#NormalTok("Residuals   1040.17 110                      ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
#Skylighting(([#FunctionTok("eta_squared");#NormalTok("(jury_acov_sum, ");#AttributeTok("alternative =");#NormalTok(" ");#StringTok("\"two.sided\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# Effect Size for ANOVA (Type III)");],
[],
[#NormalTok("Parameter | Eta2 (partial) |       95% CI");],
[#NormalTok("-----------------------------------------");],
[#NormalTok("Attr      |           0.07 | [0.00, 0.16]");],
[#NormalTok("Serious   |           0.27 | [0.14, 0.39]");],));
]
#Skylighting(([#CommentTok("# Another way using rstatix");],
[#NormalTok("jury_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("anova_test");#NormalTok("(Years ");#SpecialCharTok("~");#NormalTok(" Attr ");#SpecialCharTok("+");#NormalTok(" Serious, ");#AttributeTok("effect.size =");#NormalTok(" ");#StringTok("\"pes\"");#NormalTok(", ");#AttributeTok("type =");#NormalTok(" ");#DecValTok("3");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("ANOVA Table (type III tests)");],
[],
[#NormalTok("   Effect DFn DFd      F       p p<.05   pes");],
[#NormalTok("1    Attr   2 110  3.873 2.4e-02     * 0.066");],
[#NormalTok("2 Serious   1 110 40.307 5.0e-09     * 0.268");],));
]
]
What do we see? Well, the main effect of attractiveness is now significant (#emph[F]\(2, 110) = 3.87, #emph[p] = .024, $eta_p^2$ = .07, 95% CI = \[0, .16\]). The effect of the covariate is also significant (#emph[F]\(1, 110) = 40.31, #emph[p] \< .001, $eta_p^2$ = .27, 95% CI = \[.14, .39\]).

What's actually going on here? Well, the first model showed us that by itself, attractiveness was not a significant part of the model. However, once we factored in the effect of Seriousness (and more importantly, controlled for it) we saw that Attractive #emph[did] in fact relate to the sentence length. Unsurprisingly, the seriousness of the crime also predicted sentence length.

=== Assumptions
<assumptions-2>
By and large, the assumptions required for an ANCOVA are the same as that of a regular ANOVA. However, there are two new ones in bold below:

- Normality of residuals
- Homogeneity of variances
- #strong[Linearity of the covariate]
- #strong[Homogeneity of regression slopes]

Let's check each of these below.

First, the normality of residuals can simply be tested as in the usual way. Our residuals are not normally distributed in this model (#emph[W] = .97, #emph[p] = .006).

#block[
#Skylighting(([#FunctionTok("shapiro.test");#NormalTok("(jury_acov");#SpecialCharTok("$");#NormalTok("residuals)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  jury_acov$residuals");],
[#NormalTok("W = 0.96616, p-value = 0.005529");],));
]
]
The homoegeneity of variance assumption is also largely tested in the same way. Our homogeneity of variance assumption also isn't met (#emph[F]\(2, 111) = 5.68, #emph[p] = .004)…

#block[
#Skylighting(([#NormalTok("jury_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("levene_test");#NormalTok("(Years ");#SpecialCharTok("~");#NormalTok(" Attr, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Warning in leveneTest.default(y = y, group = group, ...): group coerced to");],
[#NormalTok("factor.");],));
]
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 4");],
[#NormalTok("    df1   df2 statistic       p");],
[#NormalTok("  <int> <int>     <dbl>   <dbl>");],
[#NormalTok("1     2   111      5.68 0.00446");],));
]
]
=== Linearity of the covariate
<linearity-of-the-covariate>
A third assumption tests whether the covariate is linearly related to the DV. This assumption is essentially similar to the linearity assumption in a regression model - because we are still dealing with linear models, our covariates must also be linearly related to our outcome.

This is simple enough to test just by visualising the relationship. In general, this assumption appears to hold - it looks like there's a vague linear relationship in there.

\(Note that due to the data being in integers - i.e.~whole numbers - I've used #NormalTok("geom_jitter()"); in place of #NormalTok("geom_point()"); to help visualise this a bit better.)

#Skylighting(([#NormalTok("jury_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" Serious, ");#AttributeTok("y =");#NormalTok(" Years)");],
[#NormalTok("  ) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_jitter");#NormalTok("() ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Perceived seriousness of crime\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Sentence length (Years)\"");#NormalTok(")");],));
#align(center)[#box(image("09-regressions-2_files/figure-typst/unnamed-chunk-7-1.svg"))]
Finally, the #strong[homogeneity of regression slopes] assumption specifies that for each group, the slope of the relationship between the covariate and the dependent variable are the same. To test this, we need to run an ANOVA that allows for an interaction between the predictor and covariate.

#block[
#Skylighting(([#NormalTok("jury_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("anova_test");#NormalTok("(Years ");#SpecialCharTok("~");#NormalTok(" Attr ");#SpecialCharTok("*");#NormalTok(" Serious, ");#AttributeTok("effect.size =");#NormalTok(" ");#StringTok("\"pes\"");#NormalTok(", ");#AttributeTok("type =");#NormalTok(" ");#DecValTok("3");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("ANOVA Table (type III tests)");],
[],
[#NormalTok("        Effect DFn DFd      F        p p<.05   pes");],
[#NormalTok("1         Attr   2 108  0.951 3.90e-01       0.017");],
[#NormalTok("2      Serious   1 108 42.794 2.09e-09     * 0.284");],
[#NormalTok("3 Attr:Serious   2 108  3.622 3.00e-02     * 0.063");],));
]
]
Uh oh - this isn't good. A significant interaction suggests that the slope of the relationship between #NormalTok("Serious"); and #NormalTok("Years"); differs for each level of attractiveness, as indicated by the significant interaction effect (#emph[p] = .03). We can see as much if we fit separate regression lines to the scatterplot above:

#Skylighting(([#NormalTok("jury_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" Serious, ");#AttributeTok("y =");#NormalTok(" Years, ");#AttributeTok("colour =");#NormalTok(" Attr)");],
[#NormalTok("  ) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("geom_jitter");#NormalTok("() ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Perceived seriousness of crime\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Sentence length (Years)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_smooth");#NormalTok("(");#AttributeTok("method =");#NormalTok(" lm, ");#AttributeTok("se =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("`geom_smooth()` using formula = 'y ~ x'");],));
]
#align(center)[#box(image("09-regressions-2_files/figure-typst/unnamed-chunk-9-1.svg"))]
As we can clearly see, the slopes are not identical for each group. In particular, the Unattractive group has a much stronger slope between seriousness and sentence length (indicating that unattractive people basically have it harder if they're perceived to have committed more serious crimes).

Overall, given that many of our assumptions are not met - particularly the important one of homogeneity of regression slopes - this indicates that an ANCOVA isn't a suitable model for our data. What would we do in this instance, then? We'd probably model a regression that allows for the interaction between attractiveness and seriousness.

A final note on ANCOVAs: naturally, we can extend an ANCOVA model to have multiple predictors #emph[and] multiple covariates. In this instance, we would need to model multi-way interactions to test all of our effects and assumptions. Below is a lightly annotated example of a two-way ANCOVA using attractiveness and type of crime as predictors, seriousness as a covariate and sentence length as an outcome.

#Skylighting(([#CommentTok("# Build two way ANCOVA");],
[#NormalTok("jury_twoway_acov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov");#NormalTok("(Years ");#SpecialCharTok("~");#NormalTok(" Attr ");#SpecialCharTok("*");#NormalTok(" Crime ");#SpecialCharTok("+");#NormalTok(" Serious, ");#AttributeTok("data =");#NormalTok(" jury_data)");],
[],
[#CommentTok("# Normality of residuals");],
[#FunctionTok("shapiro.test");#NormalTok("(jury_twoway_acov");#SpecialCharTok("$");#NormalTok("residuals)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  jury_twoway_acov$residuals");],
[#NormalTok("W = 0.96895, p-value = 0.009416");],));
]
#Skylighting(([#CommentTok("# Homogeneity of variance");],
[#NormalTok("jury_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("levene_test");#NormalTok("(Years ");#SpecialCharTok("~");#NormalTok(" Attr ");#SpecialCharTok("*");#NormalTok(" Crime, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 4");],
[#NormalTok("    df1   df2 statistic      p");],
[#NormalTok("  <int> <int>     <dbl>  <dbl>");],
[#NormalTok("1     5   108      3.14 0.0111");],));
]
#Skylighting(([#CommentTok("# Linearity of covariate + homogeneity of regression slopes");],
[],
[#NormalTok("jury_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" Serious, ");#AttributeTok("y =");#NormalTok(" Years, ");#AttributeTok("colour =");#NormalTok(" Attr)");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_jitter");#NormalTok("() ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Perceived seriousness of crime\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Sentence length (Years)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_smooth");#NormalTok("(");#AttributeTok("method =");#NormalTok(" lm, ");#AttributeTok("se =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("facet_wrap");#NormalTok("(");#SpecialCharTok("~");#NormalTok("Crime)");],));
#block[
#Skylighting(([#NormalTok("`geom_smooth()` using formula = 'y ~ x'");],));
]
#box(image("09-regressions-2_files/figure-typst/unnamed-chunk-10-1.svg"))

#Skylighting(([#NormalTok("jury_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("anova_test");#NormalTok("(Years ");#SpecialCharTok("~");#NormalTok(" Attr ");#SpecialCharTok("*");#NormalTok(" Crime ");#SpecialCharTok("*");#NormalTok(" Serious, ");#AttributeTok("effect.size =");#NormalTok(" ");#StringTok("\"pes\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("ANOVA Table (type II tests)");],
[],
[#NormalTok("              Effect DFn DFd      F        p p<.05   pes");],
[#NormalTok("1               Attr   2 102  4.179 1.80e-02     * 0.076");],
[#NormalTok("2              Crime   1 102  0.403 5.27e-01       0.004");],
[#NormalTok("3            Serious   1 102 42.943 2.34e-09     * 0.296");],
[#NormalTok("4         Attr:Crime   2 102  2.955 5.70e-02       0.055");],
[#NormalTok("5       Attr:Serious   2 102  3.977 2.20e-02     * 0.072");],
[#NormalTok("6      Crime:Serious   1 102  0.658 4.19e-01       0.006");],
[#NormalTok("7 Attr:Crime:Serious   2 102  0.672 5.13e-01       0.013");],));
]
#Skylighting(([#CommentTok("# Output ANCOVA");],
[#FunctionTok("Anova");#NormalTok("(jury_twoway_acov, ");#AttributeTok("type =");#NormalTok(" ");#DecValTok("3");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Anova Table (Type III tests)");],
[],
[#NormalTok("Response: Years");],
[#NormalTok("            Sum Sq  Df F value    Pr(>F)    ");],
[#NormalTok("(Intercept)   5.32   1  0.5767   0.44927    ");],
[#NormalTok("Attr         80.42   2  4.3592   0.01514 *  ");],
[#NormalTok("Crime         4.43   1  0.4800   0.48991    ");],
[#NormalTok("Serious     379.49   1 41.1423 3.938e-09 ***");],
[#NormalTok("Attr:Crime   49.30   2  2.6723   0.07370 .  ");],
[#NormalTok("Residuals   986.95 107                      ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
== Hierarchical regression
<hierarchical-regression>
Hierarchical regression is a form of multiple regression where we test the effects of predictors in #strong[blocks.] The aim of doing a hierarchical regression is generally to test theoretical predictions about the effects of specific variables, especially before/after we control for other variables. The other aim is to explore how the #emph[model] changes after we add additional predictors into the model.

The basic principle of a hierarchical regression is something like this:

+ Start by defining block 1, which is our basic regression model. This is the regression we start with. Run the regression defined in block 1.
+ Identify which variables will be entered into block 2, which is the first round of additional predictors
+ Run a second multiple regression with all predictors in block 2.
+ Compare block 1 with block 2 in terms of overall model fit.

The choice of what variables to enter in which blocks must be guided by theory - in other words, you cannot simply add variables at random.

=== Example
<example-7>
Let's return to the proneness to flow example introduced in the multiple regression section. As a reminder, here are our variables:

- Trait anxiety: broadly, refers to people's tendency to feel anxious
- Openness to experience: a personality trait that describes how likely people are to seek new experiences
- DFS\_Total: a measure of proneness to flow.
- age: participant's age.

#block[
#Skylighting(([#NormalTok("flow_data ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_10\"");#NormalTok(", ");#StringTok("\"w10_flow.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 811 Columns: 6");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("dbl (6): id, age, GoldMSI, DFS_Total, trait_anxiety, openness");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
In the first regressions module, we simply ran everything in one go as a multiple regression. Now let's imagine we want to run this as a hierarchical regression, with the following blocks:

- Block 1: GOld MSI predicting proneness to flow (DFS\_Total)
- Block 2: Gold MSI and openness predicting proneness to flow
- Block 3: Gold MSI, openness and trait anxiety predicting proneness to flow

The assumption tests in multiple regressions are identical for hierarchical regressions.

=== Building blocks and output
<building-blocks-and-output>
Let's start by building block 1. We can do this with #NormalTok("lm()"); as per normal. I will call this #NormalTok("flow_block1");:

#block[
#Skylighting(([#NormalTok("flow_block1 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(DFS_Total ");#SpecialCharTok("~");#NormalTok(" GoldMSI, ");#AttributeTok("data =");#NormalTok(" flow_data)");],));
]
To build block 2, we simply need to create a new regression model with both predictors, as if we were running this in one go:

#block[
#Skylighting(([#NormalTok("flow_block2 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(DFS_Total ");#SpecialCharTok("~");#NormalTok(" GoldMSI ");#SpecialCharTok("+");#NormalTok(" openness, ");#AttributeTok("data =");#NormalTok(" flow_data)");],));
]
Finally, we do the same thing for block 3:

#block[
#Skylighting(([#NormalTok("flow_block3 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(DFS_Total ");#SpecialCharTok("~");#NormalTok(" GoldMSI ");#SpecialCharTok("+");#NormalTok(" openness ");#SpecialCharTok("+");#NormalTok(" trait_anxiety, ");#AttributeTok("data =");#NormalTok(" flow_data)");],));
]
Now let's print the summary of each model. We can see in block 1 that Gold MSI scores significantly predict proneness to flow:

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(flow_block1)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = DFS_Total ~ GoldMSI, data = flow_data)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("     Min       1Q   Median       3Q      Max ");],
[#NormalTok("-14.1367  -2.4567   0.0448   2.2783  12.2886 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("            Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)  16.3429     1.0848   15.06   <2e-16 ***");],
[#NormalTok("GoldMSI       2.9231     0.1983   14.74   <2e-16 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 3.538 on 809 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.2118,    Adjusted R-squared:  0.2108 ");],
[#NormalTok("F-statistic: 217.4 on 1 and 809 DF,  p-value: < 2.2e-16");],));
]
]
In Block 2, both the Gold MSI and openness are significant predictors of flow proneness.

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(flow_block2)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = DFS_Total ~ GoldMSI + openness, data = flow_data)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("     Min       1Q   Median       3Q      Max ");],
[#NormalTok("-14.3099  -2.3925   0.0643   2.2613  11.6213 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("            Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)  14.6287     1.1912  12.281  < 2e-16 ***");],
[#NormalTok("GoldMSI       2.7179     0.2061  13.185  < 2e-16 ***");],
[#NormalTok("openness      0.4818     0.1425   3.382 0.000755 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 3.515 on 808 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.2228,    Adjusted R-squared:  0.2209 ");],
[#NormalTok("F-statistic: 115.8 on 2 and 808 DF,  p-value: < 2.2e-16");],));
]
]
Finally, in block 3 we can see that all three remain significant predictors. However, the effect of openness to experience has changed slightly (an unreliable heuristic for this is that the p-value has increased):

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(flow_block3)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = DFS_Total ~ GoldMSI + openness + trait_anxiety, ");],
[#NormalTok("    data = flow_data)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("     Min       1Q   Median       3Q      Max ");],
[#NormalTok("-15.0424  -2.2409  -0.0931   2.1484  12.3474 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("              Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)   21.08246    1.33150  15.834   <2e-16 ***");],
[#NormalTok("GoldMSI        2.66545    0.19623  13.583   <2e-16 ***");],
[#NormalTok("openness       0.29958    0.13700   2.187   0.0291 *  ");],
[#NormalTok("trait_anxiety -0.10662    0.01154  -9.237   <2e-16 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 3.345 on 807 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.2971,    Adjusted R-squared:  0.2945 ");],
[#NormalTok("F-statistic: 113.7 on 3 and 807 DF,  p-value: < 2.2e-16");],));
]
]
On the next page we'll talk about model comparison in a more formal manner. However, if we wanted to write these results up we would need to talk about the results from each block. For example:

A hierarchical regression was conducted to examine the effect

== Comparing models
<comparing-models>
On the previous page, we ended up with three models relating to the flow data. That's all well and good, and seeing how each model changed the predictors was valuable in its own right. But how do we actually… decide which model to run with?

=== Comparing $R^2$
<comparing-r2>
The most commonly cited method of comparing between regression models is to examine their $R^2$ values, which you may recall is a measure of how much variance in the outcome is explained by the predictors.

This is easy enough to do visually. You can see the $R^2$ values in the output. We can extract this easily using the following code. Whenever we use #NormalTok("summary()"); on an #NormalTok("lm()"); model, the summary object will contain a variable for the $R^2$ that we can easily pull:

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(flow_block1)");#SpecialCharTok("$");#NormalTok("r.squared");],));
#block[
#Skylighting(([#NormalTok("[1] 0.211779");],));
]
#Skylighting(([#FunctionTok("summary");#NormalTok("(flow_block2)");#SpecialCharTok("$");#NormalTok("r.squared");],));
#block[
#Skylighting(([#NormalTok("[1] 0.22278");],));
]
#Skylighting(([#FunctionTok("summary");#NormalTok("(flow_block3)");#SpecialCharTok("$");#NormalTok("r.squared");],));
#block[
#Skylighting(([#NormalTok("[1] 0.2971018");],));
]
]
We can see that Block 3 has the highest $R^2$ at .297, meaning that the Block 3 model explains about 29.7% of the variance in the outcome. Block 2 explains 22.3% while Block 1 explains 21.2%. Therefore, based on this alone we might say that Block 2 explains only a little bit of extra variance in flow proneness than Block 1, while Block 3 explains substantially more - therefore, we should go with Block 3. However… $R^2$ will #emph[always] increase with more predictors! The very fact that each additional predictor will explain more variance - even if only a tiny amount at a time - means that selecting based on $R^2$ alone will naturally favour models with more predictors. This isn't necessarily a useful thing!

=== Nested model tests
<nested-model-tests>
This is a slightly more 'formal' test of whether a more complex model leads to a significant change in fit. This works by comparing #strong[nested] models. Imagine model A and model B, two linear regressions fit on the same dataset. Model A has three predictors, and is the 'full' model of the thing we're trying to the estimate. Model B drops one of the predictors from Model A, but keeps the other two. Model B is considered a #emph[nested] model of Model A.

The principle of this test is based on the idea of seeing whether a nested (reduced) model is a significantly better fit than a full model. If a nested model is a better fit, the residual sums of squares will #emph[decrease] - less residuals indicate better fit. The #NormalTok("anova()"); test works on this principle, but in a sort of reverse way. Because we're testing whether a model with #emph[additional] predictors is a better fit, naturally we should expect that the 'nested' model (in this case, our original model) will be a #emph[worse] fit than the new model. In that case, a significant result indicates that the more complex model is the better fit.

Nested model tests can be done with the #NormalTok("anova()"); function from base R by simply giving it two model names in order. Let's start by comparing Blocks 1 and 2:

#block[
#Skylighting(([#FunctionTok("anova");#NormalTok("(flow_block1, flow_block2)");],));
#block[
#Skylighting(([#NormalTok("Analysis of Variance Table");],
[],
[#NormalTok("Model 1: DFS_Total ~ GoldMSI");],
[#NormalTok("Model 2: DFS_Total ~ GoldMSI + openness");],
[#NormalTok("  Res.Df     RSS Df Sum of Sq      F    Pr(>F)    ");],
[#NormalTok("1    809 10124.2                                  ");],
[#NormalTok("2    808  9982.9  1     141.3 11.437 0.0007547 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
]
And now between Blocks 2 and 3:

#block[
#Skylighting(([#FunctionTok("anova");#NormalTok("(flow_block2, flow_block3)");],));
#block[
#Skylighting(([#NormalTok("Analysis of Variance Table");],
[],
[#NormalTok("Model 1: DFS_Total ~ GoldMSI + openness");],
[#NormalTok("Model 2: DFS_Total ~ GoldMSI + openness + trait_anxiety");],
[#NormalTok("  Res.Df    RSS Df Sum of Sq      F    Pr(>F)    ");],
[#NormalTok("1    808 9982.9                                  ");],
[#NormalTok("2    807 9028.3  1    954.62 85.329 < 2.2e-16 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
]
From this, we can conclude that Block 2 is a better fit to the data than Block 1 (F(1, 808) = 11.437, #emph[p] \< .001), and also that Block 3 is again a better fit than Block 2 (F(1, 807) = 85.329, #emph[p] \< .001). Therefore, using this method we would consider using the model in Block 3 for interpretation, as this provides a better fit of the data. This sort of lines up with what we saw with the $R^2$ change (but this probably won't always be the case).

=== Fit indices
<fit-indices>
An alternative approach is to use #strong[fit indices], which are various measures that essentially indicate how well a model fits the data. Importantly, unlike $R^2$ these measures penalise based on the complexity of the model - i.e.~models with more predictors are penalised more due to their complexity.

Two of the most widely used fit indices are the #strong[Akaike Information Criterion (AIC)] and the #strong[Bayesian Information Criterion (BIC)]. They work similarly, but are just calculated in slightly different ways.

The AIC and BIC are calculated by:

$ A I C = 2 k - 2 l n \( hat(L) \) $

$ B I C = k l n \( n \) - 2 l n \( hat(L) \) $

$hat(L)$ is called the #strong[likelihood], which is a whole thing that we won't dive too much into. However, $2 l n \( hat(L) \)$ - or -2LL, or minus two log likelihood - goes by the name of #strong[deviance] (as in deviation). Deviance is essentially the residual sum of squares, and thus serves as a measure of model fit.

R provides some really neat functions called - you guessed it - #NormalTok("AIC()"); and #NormalTok("BIC()");. These will calculate the AIC and BIC values for every model name you give it. So, we can enter all of our values at once:

#block[
#Skylighting(([#FunctionTok("AIC");#NormalTok("(flow_block1, flow_block2, flow_block3)");],));
#block[
#Skylighting(([#NormalTok("            df      AIC");],
[#NormalTok("flow_block1  3 4354.820");],
[#NormalTok("flow_block2  4 4345.421");],
[#NormalTok("flow_block3  5 4265.907");],));
]
#Skylighting(([#FunctionTok("BIC");#NormalTok("(flow_block1, flow_block2, flow_block3)");],));
#block[
#Skylighting(([#NormalTok("            df      BIC");],
[#NormalTok("flow_block1  3 4368.915");],
[#NormalTok("flow_block2  4 4364.214");],
[#NormalTok("flow_block3  5 4289.398");],));
]
]
We can see that Block 3 has the lowest AIC and BIC values, meaning that it is the best fit.

== Outliers
<outliers>
Up until this point, we've largely worked without considering outliers in our data. Outliers, however, are important for any and all analyses that we do, because they have an impact on our statistics.

An intuitive reason is simply because of the fact that many of our statistics involve differences between means - such as #emph[t]-tests and ANOVAs - and means are susceptible to outliers. Consider the following set of values:

#block[
#Skylighting(([#NormalTok("vector_b ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("4");#NormalTok(", ");#DecValTok("2");#NormalTok(")");],));
]
If we take a mean, this is fairly straightforward:

#block[
#Skylighting(([#FunctionTok("mean");#NormalTok("(vector_b)");],));
#block[
#Skylighting(([#NormalTok("[1] 2.4");],));
]
]
However, imagine we have an outlier in one of our datapoints:

#block[
#Skylighting(([#NormalTok("vector_b ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", ");#DecValTok("2");#NormalTok(", ");#DecValTok("50");#NormalTok(", ");#DecValTok("2");#NormalTok(")");],
[#FunctionTok("mean");#NormalTok("(vector_b)");],));
#block[
#Skylighting(([#NormalTok("[1] 11.6");],));
]
]
Our estimate is now wildly different due to this outlier. Here's another visualisation of this effect at play, with a simple regression model:

#align(center)[#box(image("09-regressions-2_files/figure-typst/unnamed-chunk-25-1.svg"))]
You can see that in the graph on the left, there are no visible outliers, while the graph on the right has a very clear outlier (the dot at the very top). The resulting estimate of the correlation is vastly different - #emph[r] = .57 without the outlier, vs #emph[r] = .21 with it included!

In short, outliers have the potential to distort our estimates. Therefore, being able to systematically identify outliers and handle them is an important step in any analysis.

Although outliers are worth considering across all types of analyses, we'll only consider them in context of regression models here for parity with Jamovi.

Aside from visual inspection, we have two main methods of identifying outliers in our regression models. For both examples, we will use #NormalTok("flow_block3"); from the previous page.

=== Cook's distance
<cooks-distance>
#strong[Cook's distances] are a method for identifying #strong[influential points] in a regression model. The basic rationale is that if a point is highly influential, it has a large effect in shaping the overall parameter estimates in the regression model. Thus, points with high Cook's distances values are worth looking into.

Cook's distances can be easily calculated using the #NormalTok("cooks.distance()"); function in base R. You just need to apply the name of the regression model (created using #NormalTok("lm()");):

#block[
#Skylighting(([#NormalTok("flow_cooksd ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cooks.distance");#NormalTok("(flow_block3)");],));
]
This returns a singular vector of Cook's distance values. We can then perform basic descriptives on this variable to get a sense of the range of Cook's distance values:

#block[
#Skylighting(([#FunctionTok("mean");#NormalTok("(flow_cooksd)");],));
#block[
#Skylighting(([#NormalTok("[1] 0.001356221");],));
]
#Skylighting(([#FunctionTok("sd");#NormalTok("(flow_cooksd)");],));
#block[
#Skylighting(([#NormalTok("[1] 0.00316087");],));
]
#Skylighting(([#FunctionTok("median");#NormalTok("(flow_cooksd)");],));
#block[
#Skylighting(([#NormalTok("[1] 0.0004290943");],));
]
#Skylighting(([#FunctionTok("min");#NormalTok("(flow_cooksd)");],));
#block[
#Skylighting(([#NormalTok("[1] 5.657846e-10");],));
]
#Skylighting(([#FunctionTok("max");#NormalTok("(flow_cooksd)");],));
#block[
#Skylighting(([#NormalTok("[1] 0.05169864");],));
]
]
If you prefer a tidyverse implementation, you can use the #NormalTok("augment()"); function from the #NormalTok("broom"); package (see #link(<broom-augment>)[the appendix] for more information on #NormalTok("broom");). This returns a whole range of values, including fitted values, residuals (both of which are useful for Q-Q plots) and Cook's distances:

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(broom)");],
[#NormalTok("flow_extra ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("augment");#NormalTok("(flow_block3)");],
[],
[#NormalTok("flow_extra");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 811 × 10");],
[#NormalTok("   DFS_Total GoldMSI openness trait_anxiety .fitted   .resid    .hat .sigma");],
[#NormalTok("       <dbl>   <dbl>    <dbl>         <dbl>   <dbl>    <dbl>   <dbl>  <dbl>");],
[#NormalTok(" 1      30.5    5.61      5.5            54    31.9 -1.43    0.00203   3.35");],
[#NormalTok(" 2      29.2    5.44      5              66    30.0 -0.793   0.00581   3.35");],
[#NormalTok(" 3      27.5    5.06      4.5            58    29.7 -2.23    0.00479   3.35");],
[#NormalTok(" 4      33      5.56      6              44    33.0 -0.00839 0.00144   3.35");],
[#NormalTok(" 5      31      4         6.5            52    28.1  2.85    0.0105    3.35");],
[#NormalTok(" 6      34.2    6         5.5            45    33.9  0.325   0.00297   3.35");],
[#NormalTok(" 7      30.2    5.33      6.5            41    32.9 -2.61    0.00241   3.35");],
[#NormalTok(" 8      34.5    6.11      6.5            36    35.5 -0.977   0.00414   3.35");],
[#NormalTok(" 9      25      4.17      5.5            52    28.3 -3.30    0.00641   3.34");],
[#NormalTok("10      29.8    5.83      6              47    33.4 -3.66    0.00173   3.34");],
[#NormalTok("# ℹ 801 more rows");],
[#NormalTok("# ℹ 2 more variables: .cooksd <dbl>, .std.resid <dbl>");],));
]
]
The Cook's distances are contained in the #NormalTok(".cooksd"); column - note the full stop in front of the name is part of the column name.

As this returns a dataframe, we can then use normal tidyverse functions to wrangle this like any other dataframe.

#block[
#Skylighting(([#NormalTok("flow_extra ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("mean =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(.cooksd),");],
[#NormalTok("    ");#AttributeTok("sd =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(.cooksd),");],
[#NormalTok("    ");#AttributeTok("median =");#NormalTok(" ");#FunctionTok("median");#NormalTok("(.cooksd),");],
[#NormalTok("    ");#AttributeTok("min =");#NormalTok(" ");#FunctionTok("min");#NormalTok("(.cooksd),");],
[#NormalTok("    ");#AttributeTok("max =");#NormalTok(" ");#FunctionTok("max");#NormalTok("(.cooksd)");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 5");],
[#NormalTok("     mean      sd   median      min    max");],
[#NormalTok("    <dbl>   <dbl>    <dbl>    <dbl>  <dbl>");],
[#NormalTok("1 0.00136 0.00316 0.000429 5.66e-10 0.0517");],));
]
]
Base R also provides an easy way of visualising Cook's distances in regression models using #NormalTok("plot()");. To do this, you just feed in the name of the regression model (much like how you check for homoscedasticity during regression diagnostics). Note that #NormalTok("which = 4"); must be specified.

#Skylighting(([#FunctionTok("plot");#NormalTok("(flow_block3, ");#AttributeTok("which =");#NormalTok(" ");#DecValTok("4");#NormalTok(")");],));
#box(image("09-regressions-2_files/figure-typst/unnamed-chunk-30-1.svg"))

R will automatically label points that it thinks are influential data points in this plot. Based on this, data points 539, 627 and 789 might be worth a closer look.

How might you identify influential data points in general? There are #emph[many] rules of thumb out there for Cook's distances. Cook's original guideline was to flag any point with a distance \> 1, but this might be relatively rare (note that our maximum distance in this model is 0.05!). Other rules include $frac(2 k, 4)$, where #emph[k] is the number of predictors in the model, $4 / n$ where #emph[n] = sample size, and $2 sqrt(k / n)$. Truthfully, there is no singular metric that applies, so it's up to you to choose one and apply it consistently.

=== Mahalanobis' distance, $D^2$
<mahalanobis-distance-d2>
Mahalanobis' distance, $D^2$, is a measure of #emph[multivariate] outliers - ie. outliers across two or more predictors. The basic idea is that it is the literal distance between a 'cloud' of all of the predictors in your model. Outliers can be described as data points that are the furthest away from the centre of this 'cloud', quantified by having a high Mahalanobis distance.

Generating Mahalanobis' distances in R is not difficult, and can be calculated using the #NormalTok("mahalanobis_distance()"); function from the #NormalTok("rstatix");. This needs to be piped from the original dataset, and given the names of the #emph[predictors] in the regression model.

In this case, as we are working with three predictors in this model - Gold-MSI scores, trait anxiety and openness - we give the names of these variables from our dataframe to this function.

#block[
#Skylighting(([#NormalTok("flow_data ");#OtherTok("<-");#NormalTok(" flow_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mahalanobis_distance");#NormalTok("(GoldMSI, trait_anxiety, openness)");],
[],
[#NormalTok("flow_data");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 811 × 8");],
[#NormalTok("      id   age GoldMSI DFS_Total trait_anxiety openness mahal.dist is.outlier");],
[#NormalTok("   <dbl> <dbl>   <dbl>     <dbl>         <dbl>    <dbl>      <dbl> <lgl>     ");],
[#NormalTok(" 1     1    24    5.61      30.5            54      5.5      0.649 FALSE     ");],
[#NormalTok(" 2     2    30    5.44      29.2            66      5        3.71  FALSE     ");],
[#NormalTok(" 3     3    25    5.06      27.5            58      4.5      2.88  FALSE     ");],
[#NormalTok(" 4     4    22    5.56      33              44      6        0.168 FALSE     ");],
[#NormalTok(" 5     5    18    4         31              52      6.5      7.48  FALSE     ");],
[#NormalTok(" 6     6    20    6         34.2            45      5.5      1.41  FALSE     ");],
[#NormalTok(" 7     7    23    5.33      30.2            41      6.5      0.954 FALSE     ");],
[#NormalTok(" 8     8    23    6.11      34.5            36      6.5      2.36  FALSE     ");],
[#NormalTok(" 9     9    20    4.17      25              52      5.5      4.20  FALSE     ");],
[#NormalTok("10    10    25    5.83      29.8            47      6        0.399 FALSE     ");],
[#NormalTok("# ℹ 801 more rows");],));
]
]
Note that this function will automatically flag whether a datapoint is an outlier. This is essentially done by calculating a critical Mahalanobis distance at #emph[p] \< .001. Any datapoint that sits above this critical Mahalanobis distance is flagged as an outlier (see expanded details below under "How do Mahalanobis distances work?")

We can view which datapoints are flagged as outliers by simply filtering our dataset using #NormalTok("filter()");:

#block[
#Skylighting(([#NormalTok("flow_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(is.outlier ");#SpecialCharTok("==");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 2 × 8");],
[#NormalTok("     id   age GoldMSI DFS_Total trait_anxiety openness mahal.dist is.outlier");],
[#NormalTok("  <dbl> <dbl>   <dbl>     <dbl>         <dbl>    <dbl>      <dbl> <lgl>     ");],
[#NormalTok("1   378    32    4.83      29              38      2         21.0 TRUE      ");],
[#NormalTok("2   528    24    5.72      30.2            65      2.5       17.7 TRUE      ");],));
]
]
Here, we can see that participants 378 and 528 are multivariate outliers, and thus we may want to consider doing something about them.

How do Mahalanobis distances work?
#block(fill: rgb("#f0f0f0"))[
The basic principle behind using Mahalanobis distances is basically the same as Cook's distances: if a datapoint has a distance value greater than a specified cutoff, it is a multivariate outlier. The main difference is that $D^2$ is used for identifying multivariate outliers, as described above, and is empirically tested against a specified distribution (as opposed to Cook's distances, where influential outliers are mainly identified on vibes).

Mahalanobis distances follow a chi-square distribution, with the degrees of freedom being equal to the number of predictors (#emph[k]) in a model. The significance level for $D^2$ is conventionally set at #emph[p] \< .001. In essence, any datapoint that has a $D^2$ greater than a cutoff point on a chi-square distribution, given df = #emph[k] and at #emph[p] \< .001, is considered a significant outlier.

To calculate Mahalanobis distances by hand, you can use the #NormalTok("mahalanobis()"); function from base R. To do this, you need to give the function a dataframe with just the predictors in it.

#block[
#Skylighting(([#NormalTok("flow_temp ");#OtherTok("<-");#NormalTok(" flow_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(GoldMSI, trait_anxiety, openness)");],
[],
[#FunctionTok("head");#NormalTok("(flow_temp)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 3");],
[#NormalTok("  GoldMSI trait_anxiety openness");],
[#NormalTok("    <dbl>         <dbl>    <dbl>");],
[#NormalTok("1    5.61            54      5.5");],
[#NormalTok("2    5.44            66      5  ");],
[#NormalTok("3    5.06            58      4.5");],
[#NormalTok("4    5.56            44      6  ");],
[#NormalTok("5    4               52      6.5");],
[#NormalTok("6    6               45      5.5");],));
]
]
Then, feed it into the #NormalTok("mahalanobis()"); function as below. Note the extra arguments; #NormalTok("colMeans(flow_temp)"); specifies the means of the columns (i.e.~the variables), and #NormalTok("cov(flow_temp)"); generates the variance-covariance matrix between these variables.

#block[
#Skylighting(([#NormalTok("mahal ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("mahalanobis");#NormalTok("(flow_temp, ");#FunctionTok("colMeans");#NormalTok("(flow_temp), ");#FunctionTok("cov");#NormalTok("(flow_temp))");],
[],
[#FunctionTok("head");#NormalTok("(mahal)");],));
#block[
#Skylighting(([#NormalTok("[1] 0.6491979 3.7060236 2.8816398 0.1675431 7.4849829 1.4083562");],));
]
]
Once we have done that we can leverage the properties of the chi-square distribution to calculate #emph[p]-values for each Mahalanobis distance. Note that df = 3 here, as our original model had 3 predictors.

#block[
#Skylighting(([#NormalTok("p ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("pchisq");#NormalTok("(mahal, ");#AttributeTok("df =");#NormalTok(" ");#DecValTok("3");#NormalTok(", ");#AttributeTok("lower.tail =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],
[],
[#FunctionTok("head");#NormalTok("(p)");],));
#block[
#Skylighting(([#NormalTok("[1] 0.88508291 0.29500801 0.41023627 0.98265060 0.05794556 0.70357717");],));
]
]
Alternatively - and this is what #NormalTok("rstatix"); does - you can calculate the Mahalanobis distance corresponding to #emph[p] = .001, which will tell you the critical Mahalanobis distance value for a significant outlier.

#block[
#Skylighting(([#FunctionTok("qchisq");#NormalTok("(");#FloatTok("0.999");#NormalTok(", ");#AttributeTok("df =");#NormalTok(" ");#DecValTok("3");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 16.26624");],));
]
]
This means that any Mahalanobis distance above 16.27 will be significant.

]
=== What happens if there is an outlier?
<what-happens-if-there-is-an-outlier>
Say that you've identified a bona fide outlier in your data. What do you do with it?

In these kinds of scenarios, the best-practice approach will most likely involve doing a #strong[sensitivity analysis]. Sensitivity analyses are a general technique that broadly refer to testing your analyses under different conditions to see whether they hold under said conditions. The basic idea here is that you run #emph[two] versions of your analyses:

+ First, a version #emph[with] the outliers.
+ Next, a version #emph[without] the outliers.

The aim is to see whether the effect(s) of interest change as a result of excluding the outliers, and by how much.

Let's see an example of this using the same model as before. Here is the original #NormalTok("flow_block3"); model, just under a different name now:

#block[
#Skylighting(([#NormalTok("flow_lm1 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(DFS_Total ");#SpecialCharTok("~");#NormalTok(" GoldMSI ");#SpecialCharTok("+");#NormalTok(" trait_anxiety ");#SpecialCharTok("+");#NormalTok(" openness, ");#AttributeTok("data =");#NormalTok(" flow_data)");],
[#FunctionTok("summary");#NormalTok("(flow_lm1)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = DFS_Total ~ GoldMSI + trait_anxiety + openness, ");],
[#NormalTok("    data = flow_data)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("     Min       1Q   Median       3Q      Max ");],
[#NormalTok("-15.0424  -2.2409  -0.0931   2.1484  12.3474 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("              Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)   21.08246    1.33150  15.834   <2e-16 ***");],
[#NormalTok("GoldMSI        2.66545    0.19623  13.583   <2e-16 ***");],
[#NormalTok("trait_anxiety -0.10662    0.01154  -9.237   <2e-16 ***");],
[#NormalTok("openness       0.29958    0.13700   2.187   0.0291 *  ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 3.345 on 807 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.2971,    Adjusted R-squared:  0.2945 ");],
[#NormalTok("F-statistic: 113.7 on 3 and 807 DF,  p-value: < 2.2e-16");],));
]
]
Now, let's remove the two outliers that we identified using Mahalanobis distances. These were participants 378 and 528. We will use #NormalTok("filter()"); for simplicity.

The code below lets us remove specific rows. Let's break down what this does:

- The exclamation mark #NormalTok("!"); before #NormalTok("id"); means "not" - i.e.~do not do what comes next.
- The #NormalTok("%in%"); operator is a special operator in R that checks if a vector of values is present in another vector.
- Here, #NormalTok("id %in% c(378, 528)"); essentially means to see whether the #NormalTok("id"); column has a 378 and 528 in it. By wrapping this in #NormalTok("filter()"); we are essentially telling R to filer the rows where #NormalTok("id"); equals 378 and 528.

However, since all of that is preceded with the exclamation mark, the code is actually telling R to filter all the rows that are #emph[not] #NormalTok("id"); = 378 or 528 - in essence, it filters these rows #emph[out]. It's a bit complex, but it's good to know as it applies to many scenarios!

#block[
#Skylighting(([#NormalTok("flow_no_outliers ");#OtherTok("<-");#NormalTok(" flow_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(");#SpecialCharTok("!");#NormalTok("id ");#SpecialCharTok("%in%");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("378");#NormalTok(", ");#DecValTok("528");#NormalTok("))");],));
]
Now that we have a dataframe without the two outliers, let's now refit our model. The only argument we need to change is the name of the dataset:

#block[
#Skylighting(([#NormalTok("flow_lm2 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(DFS_Total ");#SpecialCharTok("~");#NormalTok(" GoldMSI ");#SpecialCharTok("+");#NormalTok(" trait_anxiety ");#SpecialCharTok("+");#NormalTok(" openness, ");#AttributeTok("data =");#NormalTok(" flow_no_outliers)");],
[#FunctionTok("summary");#NormalTok("(flow_lm2)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = DFS_Total ~ GoldMSI + trait_anxiety + openness, ");],
[#NormalTok("    data = flow_no_outliers)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("     Min       1Q   Median       3Q      Max ");],
[#NormalTok("-15.0449  -2.2436  -0.1038   2.1526  12.3581 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("              Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)   21.15098    1.34199  15.761   <2e-16 ***");],
[#NormalTok("GoldMSI        2.66601    0.19680  13.547   <2e-16 ***");],
[#NormalTok("trait_anxiety -0.10694    0.01158  -9.232   <2e-16 ***");],
[#NormalTok("openness       0.29029    0.14011   2.072   0.0386 *  ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 3.348 on 805 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.2965,    Adjusted R-squared:  0.2939 ");],
[#NormalTok("F-statistic: 113.1 on 3 and 805 DF,  p-value: < 2.2e-16");],));
]
]
We can see that even without the outliers, the pattern of results is very similar to the original model we had above. Therefore, in this kind of setting we don't really gain anything by removing the outliers, and we might choose to keep the original model. Every participant lost is power lost, and the more information we have, the better! However, if your results do change substantially after excluding outliers then you will need to examine the differences carefully.

There are other methods that you could consider:

- Using a #emph[non-parametric] test, which are not affected by outliers (see #link(<nonpara>)[the section on non-parametric tests])
- Transforming the data to 'un-outlier' the outliers - this can be tricky to interpret

Regardless, it is a good idea to report both versions of the model - with and without outliers - for transparency, to show that you have actively considered these residuals.

== Partial correlations
<partial-correlations>
=== Introduction
<introduction-5>
Recall that a correlation coefficient quantifies the strength of the relationship between two variables. That is a standard (zero-order) Pearson's correlation coefficient, which is ubiquitous in just about any statistical analysis involving continuous variables.

There are many more types of correlation coefficients out there, some of which we talk about in this subject and others which we won't touch. On this page, we'll look at two extensions of Pearson's correlation coefficent in particular: #strong[partial correlations] and #strong[semipartial correlations]. Both measures are useful specifically in regression contexts. On this page, we will start with partial correlations only, and move onto semipartials in the next.

=== Partial correlations
<partial-correlations-1>
A #strong[partial correlation] quantifies the relationship between variables X and Y, while controlling for variable Z. In essence, you can imagine that the effect of Z is 'partialled out' - or removed - from the correlation between X and Y. This is useful in situations just like the one described above - when you want to control for the effect of a certain variable when calculating a correlation coefficient.

The formula for a partial correlation is:

$ r_(x y . z) = frac(r_(x y) - \( r_(x z) times r_(y z) \), sqrt(\( 1 - r_(x z)^2 \) \( 1 - r_(y z)^2 \))) $

That is, you need to know the standard correlation between variables X and Y ($r_(x y)$), the correlation between X and Z ($r_(x z)$) and the correlation between Y and Z ($r_(y z)$), and then plug them into the formula above.

Let's come back to the flow data in Week 10 once again. Imagine we want to test the correlation between Gold MSI scores and flow proneness. However, we might suspect that openness to experience may play a role in the relationship between these variables - in other words, we expect openness to experience to affect both Gold-MSI scores and flow proneness. One thing we could do is to calculate a partial correlation between MSI scores and flow proneness while controlling for openness.

If we know the correlation between:

- MSI scores and flow proneness,
- MSI scores and openness,
- Flow proneness and openness,

Then we can calculate partial correlations between MSI scores and flow proneness, controlling for openness.

In R, we can calculate both partial and semi-partial correlations using the #NormalTok("ppcor"); package. For demonstration's sake, we will filter the dataset so it only contains the three variables we are interested in here - Gold-MSI scores, openness and flow proneness - though it is not necessary to do this.

To calculate a partial correlation with a significant test, we can use the #NormalTok("pcor.test()"); function. The function needs three arguments:

- #NormalTok("x");: The first variable to correlate.
- #NormalTok("y");: The second variable to correlate.
- #NormalTok("z");: The control variable.

The output will look something like this. This looks similar enough to a standard correlation output, and you can interpret it as such. The output shows the relationship between X (Gold-MSI) and Y (DFS Total, flow proneness), while controlling for the effect of openness to experience.

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(ppcor)");],
[#FunctionTok("pcor.test");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("x =");#NormalTok(" flow_data");#SpecialCharTok("$");#NormalTok("GoldMSI,");],
[#NormalTok("  ");#AttributeTok("y =");#NormalTok(" flow_data");#SpecialCharTok("$");#NormalTok("DFS_Total,");],
[#NormalTok("  ");#AttributeTok("z =");#NormalTok(" flow_data");#SpecialCharTok("$");#NormalTok("openness");],
[#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("   estimate      p.value statistic   n gp  Method");],
[#NormalTok("1 0.4207818 4.274538e-36  13.18493 811  1 pearson");],));
]
]
Compare this to the standard correlation call below - we can see that even after controlling for openness the correlation is still significant, and doesn't decrease by a huge amount (partial #emph[r]\(809) = .42, #emph[p] \< .001).

#block[
#Skylighting(([#CommentTok("# Standard correlation");],
[#FunctionTok("cor.test");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("x =");#NormalTok(" flow_data");#SpecialCharTok("$");#NormalTok("GoldMSI,");],
[#NormalTok("  ");#AttributeTok("y =");#NormalTok(" flow_data");#SpecialCharTok("$");#NormalTok("DFS_Total");],
[#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    Pearson's product-moment correlation");],
[],
[#NormalTok("data:  flow_data$GoldMSI and flow_data$DFS_Total");],
[#NormalTok("t = 14.743, df = 809, p-value < 2.2e-16");],
[#NormalTok("alternative hypothesis: true correlation is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" 0.4041563 0.5127911");],
[#NormalTok("sample estimates:");],
[#NormalTok("      cor ");],
[#NormalTok("0.4601945 ");],));
]
]
To run multiple partial correlations, between variables, the #NormalTok("pcor()"); function will compute these given a dataset. This will calculate partial correlations between pairs of variables, controlling for every other variable included in the call to #NormalTok("pcor()");. In the example below, we fuse #NormalTok("select()"); to pull only the variables we are interested in and pipe this to #NormalTok("pcor()"); - basically, we are giving #NormalTok("pcor()"); a data frame with only the three variables of interest#footnote[Note that #NormalTok("ppcor"); loads a package called #NormalTok("MASS");, which is used for a number of advanced statistical functions. #NormalTok("MASS"); has its own #NormalTok("select()"); function, which has a quirk of overwriting the tidyverse #NormalTok("select()"); if #NormalTok("MASS");/#NormalTok("ppcor"); is loaded after tidyverse; that is, any #NormalTok("select()"); call you make might actually be #NormalTok("MASS::select()"); (which won't work for what you probably want to do) instead of #NormalTok("dplyr::select()"); (which is the column selector). The solution is to either load #NormalTok("tidyverse"); after everything else (if you're sure this won't break some other package's function), or make explicit calls to #NormalTok("dplyr"); using #NormalTok("dplyr::select()");, which is what I've done here.].

#block[
#Skylighting(([#NormalTok("flow_data ");#SpecialCharTok("%>%");],
[#NormalTok("  dplyr");#SpecialCharTok("::");#FunctionTok("select");#NormalTok("(GoldMSI, openness, DFS_Total) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pcor");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("$estimate");],
[#NormalTok("            GoldMSI  openness DFS_Total");],
[#NormalTok("GoldMSI   1.0000000 0.2154726 0.4207818");],
[#NormalTok("openness  0.2154726 1.0000000 0.1181387");],
[#NormalTok("DFS_Total 0.4207818 0.1181387 1.0000000");],
[],
[#NormalTok("$p.value");],
[#NormalTok("               GoldMSI     openness    DFS_Total");],
[#NormalTok("GoldMSI   0.000000e+00 5.794901e-10 4.274538e-36");],
[#NormalTok("openness  5.794901e-10 0.000000e+00 7.546911e-04");],
[#NormalTok("DFS_Total 4.274538e-36 7.546911e-04 0.000000e+00");],
[],
[#NormalTok("$statistic");],
[#NormalTok("            GoldMSI openness DFS_Total");],
[#NormalTok("GoldMSI    0.000000 6.272218 13.184932");],
[#NormalTok("openness   6.272218 0.000000  3.381816");],
[#NormalTok("DFS_Total 13.184932 3.381816  0.000000");],
[],
[#NormalTok("$n");],
[#NormalTok("[1] 811");],
[],
[#NormalTok("$gp");],
[#NormalTok("[1] 1");],
[],
[#NormalTok("$method");],
[#NormalTok("[1] \"pearson\"");],));
]
]
The way to read this table is to look at the #NormalTok("$estimate"); part of the output for the correlations, and the #NormalTok("$p.value"); for the corresponding #emph[p]-value. We can see that the partial correlation between Gold-MSI scores and flow proneness is where the rows/columns for DFS\_Total and GoldMSI meet.

== Semipartial correlations
<semipartial-correlations>
=== Semipartial correlations (#emph[sr])
<semipartial-correlations-sr>
#strong[Semipartial correlations] are similar in nature to partial correlations, with one key difference: the effect of the control variable Z is removed from X or Y, but not #emph[both.] In other words, the controlling/partialling out of the effect of Z happens on only one of the two variables in the correlation.

This property of semipartial correlations makes it particularly useful in multiple regressions. Imagine we have a multiple regression with outcome Y and two predictors X and Z. The amount of variance explained in Y - this is $R^2$ - is a combination of the effects of individual predictors, and the relationship between predictors. Each predictor will contribute #emph[unique] explained variance to that total amount of explained variance, and there will be some shared variance due to the relationship between predictors.

In other words, the $R^2$ for a given multiple regression can be broken down into:

- The unique variance explained by each predictor
- The shared variance between predictors, due to the relationship between the predictors

If we wanted to find out how much X #emph[uniquely] contributes to outcome Y, we could first calculate a semipartial correlation between X and Y, controlling for Z's effect on X. In essence, by removing Z's effect on X only, we are isolating any effect of X on Y specifically, allowing us to examine how much X is contributing on its own. Likewise, if we wanted to find out the unique variance explained by Z, we would run another semipartial between Z and Y, controlling for X's effect on Z.

#strong[Squaring each sr value] (i.e.~calculate $s r^2$), will give the #strong[unique amount of variance] explained by predictor X, after controlling for all other variables. If $s r^2$ for variable X is 0.1, for instance, this means that #strong[10% of the variance in Y is uniquely estimated/contributed by X]. In turn, if we calculate $s r^2$ values for each predictor, controlling for all other predictors, and subtract this from $R^2$, this will give us the shared variance.

The diagram below summarises this info (shoutout to #link("https://uq.pressbooks.pub/psychological-research-methods-workbook/chapter/activity-5-standard-and-hierarchical-multiple-regression-in-jamovi/")[UQ]:

#box(image("index_files\\mediabag\\activity-5-figure-5..png"))

=== Example
<example-8>
As an example, let's look at a regression where Gold-MSI scores, openness to experience and trait anxiety predict flow proneness. In this model, $R^2$ is .297, meaning that 29.7% of the variance is explained by all three predictors together.

The #NormalTok("ppcor"); package provides a function called #NormalTok("spcor.test()");, which works just like its #NormalTok("pcor.test()"); cousin. The only difference is that because we are now partialling the effect of control variables from the #emph[predictor] only, the order in which we enter #NormalTok("x"); and #NormalTok("y"); matters.

Namely, #NormalTok("x"); must be the #emph[outcome] variable, and #NormalTok("y"); must be the #emph[predictor] we are interested in controlling. This ensures that the control variables are correctly being removed from the predictor variable and not the outcome:

#block[
#Skylighting(([#FunctionTok("spcor.test");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("x =");#NormalTok(" flow_data");#SpecialCharTok("$");#NormalTok("DFS_Total,");],
[#NormalTok("  ");#AttributeTok("y =");#NormalTok(" flow_data");#SpecialCharTok("$");#NormalTok("GoldMSI,");],
[#NormalTok("  ");#AttributeTok("z =");#NormalTok(" flow_data[, ");#FunctionTok("c");#NormalTok("(");#StringTok("\"openness\"");#NormalTok(", ");#StringTok("\"trait_anxiety\"");#NormalTok(")]");],
[#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("   estimate      p.value statistic   n gp  Method");],
[#NormalTok("1 0.4008732 1.391025e-32   12.4304 811  2 pearson");],));
]
]
Note that #NormalTok("flow_data[, c(\"openness\", \"trait_anxiety\")]"); is simply base R notation for selecting the columns named "openness" and "trait\_anxiety" from the #NormalTok("flow_data"); dataframe.

The semipartial correlation #emph[sr] between Gold-MSI and flow proneness, controlling for the other two predictors (openness and trait anxiety) is #emph[sr] = .401, #emph[p] \< .001.

To calculate $s r 2$ you will need to square the #emph[sr] value above, which is thankfully easy enough in R:

#block[
#Skylighting(([#FloatTok("0.4008732");#SpecialCharTok("^");#DecValTok("2");],));
#block[
#Skylighting(([#NormalTok("[1] 0.1606993");],));
]
]
Squaring #emph[sr] = .401 gives us $s r^2$ = 0.1697; this means that Gold-MSI scores uniquely explain 17% of the variance in flow proneness.

=== Calculating all $s r^2$ values
<calculating-all-sr2-values>
We could continue to use the #NormalTok("spcor.test()"); function to calculate the other semipartial correlations for the other predictor and the outcome. However, just like #NormalTok("pcor()"); we have an analogous function called #NormalTok("spcor()"); that will calculate multiple semipartials in one go, using all of the variables in a provided dataframe. Like #NormalTok("pcor()");, the semipartials between two variables will be controlled for all other variables in the dataframe. In the output below, for example, the semipartial between DFS\_Total and GoldMSI controls for both openness and trait\_anxiety:

#block[
#Skylighting(([#NormalTok("flow_data ");#SpecialCharTok("%>%");],
[#NormalTok("  dplyr");#SpecialCharTok("::");#FunctionTok("select");#NormalTok("(GoldMSI, trait_anxiety, openness, DFS_Total) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("spcor");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("$estimate");],
[#NormalTok("                GoldMSI trait_anxiety    openness  DFS_Total");],
[#NormalTok("GoldMSI       1.0000000    0.09414456  0.19909165  0.4120839");],
[#NormalTok("trait_anxiety 0.1025177    1.00000000 -0.10654766 -0.3051688");],
[#NormalTok("openness      0.2178267   -0.10705287  1.00000000  0.0725823");],
[#NormalTok("DFS_Total     0.4008732   -0.27262017  0.06453483  1.0000000");],
[],
[#NormalTok("$p.value");],
[#NormalTok("                   GoldMSI trait_anxiety     openness    DFS_Total");],
[#NormalTok("GoldMSI       0.000000e+00  7.371908e-03 1.121410e-08 1.652919e-34");],
[#NormalTok("trait_anxiety 3.510562e-03  0.000000e+00 2.409483e-03 6.738338e-19");],
[#NormalTok("openness      3.815754e-10  2.296393e-03 0.000000e+00 3.901925e-02");],
[#NormalTok("DFS_Total     1.391025e-32  2.971642e-15 6.655997e-02 0.000000e+00");],
[],
[#NormalTok("$statistic");],
[#NormalTok("                GoldMSI trait_anxiety  openness DFS_Total");],
[#NormalTok("GoldMSI        0.000000      2.686366  5.771281 12.847970");],
[#NormalTok("trait_anxiety  2.927722      0.000000 -3.044107 -9.103407");],
[#NormalTok("openness       6.340209     -3.058708  0.000000  2.067352");],
[#NormalTok("DFS_Total     12.430399     -8.049422  1.837118  0.000000");],
[],
[#NormalTok("$n");],
[#NormalTok("[1] 811");],
[],
[#NormalTok("$gp");],
[#NormalTok("[1] 2");],
[],
[#NormalTok("$method");],
[#NormalTok("[1] \"pearson\"");],));
]
]
Recall that for a semipartial, we are interested in controlling the effect of other variables on the #emph[predictor] and not the outcome. To obtain the corresponding values, we read across the row labelled with the #emph[outcome] - i.e.~#NormalTok("DFS_Total"); - because this shows the semipartial correlation with each #emph[predictor] in the columns.

We can see that the semipartial correlation between flow proneness and openness is not significant (#emph[sr] = .07, #emph[p] = .067), but the semipartial correlation with trait anxiety is (#emph[sr] = -.27, #emph[p] \< .001). Squaring these values respectively gives us the following values:

- $s r^2$ for openness: 0.004 (i.e.~0.4% of variance in flow proneness)
- $s r^2$ for trait anxiety: 0.075 (i.e.~7.5% of variance in flow proneness)

If we now add all of our $s r^2$ values together, we get 0.161 + 0.004 + 0.075 = 0.249, which means that #strong[24%] of the variance in flow proneness is due to the unique effects of the individual predictors. Subtracting this number from the value for $R^2$ gives us 0.296 - 0.24 = 0.056, meaning that #strong[5.6%] of the variance in flow proneness is explained by the shared variance of all three predictors.

Sometimes, it is useful to present $s r^2$ values for each predictor as part of a standard multiple regression table. This allows a reader to see how much each predictor is contributing to the variance in the outcome. in our case, we can say that Gold MSI scores explain the most variance in the outcome, while openness accounts for very little on its own.

= Logistic regression
<logistic-regression>
This section of the book (at least for the time being) deals with #strong[logistic regression.] In some ways, we have come full circle with the inclusion of this chapter: the first statistical test we looked at were to do with categorical data, and now we make a partial return to categorical data.

While I recognise that logistic regression has an awesome application to classification and basic machine learning, the focus of this book is not on classification but prediction. Thus, we won't be diving into classification accuracy or ROC curves in the context of logistic regression, even though these are not terribly hard to implement in either R or Jamovi.

== Probability and odds
<probability-and-odds>
=== Reminder of probabilities
<reminder-of-probabilities>
Consider the following table:

#table(
  columns: 4,
  align: (left,right,right,right,),
  table.header([], [Burnout], [No burnout], [Total],),
  table.hline(),
  [Musician], [20], [4], [24],
  [Non-musician], [10], [8], [18],
  [Total], [30], [12], [42],
)
You may recall that this is a 2x2 contingency table, which we have seen before in a chi-square context. Using this table, we can work out the #emph[probability] of certain events or outcomes.

If we selected someone randomly from this table, for example, what is the probability that they would be a musician? Well, we can see that there are 24 musicians from the sample of 42, so we could simply say:

$ P \( M u s i c i a n \) = 24 / 42 = 0.57 $

Likewise, what is the probability that someone is burnt out? That would simply be:

$ P \( B u r n o u t \) = 30 / 42 = 0.71 $

What about the probability that someone is a musician #emph[and] and burnt out? We could denote this as follows:

$ P \( M u s i c i a n sect B u r n o u t \) = 20 / 42 = 0.47 $ What about the probability that someone is burnt out, given they are a musician? This would be a #emph[conditional] probability, where we are finding a probability of something on the condition that the person is burnt out. There are 24 participants who reported burnout, so our calculation would be as follows:

$ P \( B u r n o u t \| M u s i c i a n \) = 20 / 24 = 0.83 $

=== Odds
<odds>
Now, let's talk about #strong[odds.] Odds are simply the likelihood of a particular outcome occuring, and is calculated as the probability that an event will occur, divided by the probability that the event will #emph[not] occur. In other words, if the probability of an event is denoted as $A$, the probability of event $A$ not occuring is $1 - A$. We can then calculate the odds as:

$ O d d s = frac(A, 1 - A) $

Let's return to our example above, and print out the table again for ease of reference.

#table(
  columns: 4,
  align: (left,right,right,right,),
  table.header([], [Burnout], [No burnout], [Total],),
  table.hline(),
  [Musician], [20], [4], [24],
  [Non-musician], [10], [8], [18],
  [Total], [30], [12], [42],
)
What are the #emph[odds] of burnout in the musician group? To do this, we need to find the probability of burnout given they are musicians, and divide that by the probability of no burnout given they are musicians. The odds of burnout given that someone is a musician is as we saw above:

$ P \( B u r n o u t \| M u s i c i a n \) = 20 / 24 $

And the probability of someone #emph[not] burning out given that they are a musician must therefore be:

$ P \( N o med b u r n o u t \| M u s i c i a n \) = 4 / 24 $ Now we can divide these two probabilities as follows:

$ O d d s = frac(20 \/ 24, 4 \/ 24) = 20 / 4 = 5 $

What this means is that musicians are #emph[5] times as more likely to experience burnout than not experience it.

One more example. What are the odds of burnout in the non-musician group? Using the same principles as above, we can calculate this as follows.

$ P \( B u r n o u t \| N o n m u s i c i a n \) = 10 / 18 $ $ P \( N o med b u r n o u t \| N o n m u s i c i a n \) = 8 / 18 $

$ O d d s = frac(10 \/ 18, 8 \/ 18) = 10 / 8 = 1.25 $

So even non-musicians are 1.25 times more likely - or, in other words, 25% more likely - to increase burnout than not experience it.

=== Odds ratios
<odds-ratios>
Now we can take a look at the #strong[odds ratio]. The odds ratio describes how likely one #emph[outcome] is given an exposure/group, compared to another exposure/group. The odds ratio is calculated by dividing the #emph[odds] of event A by the odds of event B. The resulting value gives an indication of how much more likely event A is compared to event B, given differences in exposure.

We have already calculated two sets of odds ratios:

#block[
#set enum(numbering: "a)", start: 1)
+ The odds that a musician experiences burnout; $O d d s = 5$
+ The odds that a non-musician experiences burnout; $O d d s = 1.25$
]

We can now calculate an odds ratio for how likely a #emph[musician] is to experience burnout compared to a non-musician. We simply divide the two sets of odds:

$ O R = frac(O d d s \( A \), O d d s \( B \)) $

$ O R = 5 / 1.25 = 4 $

An odds ratio of 4 indicates that a musician is #emph[4 times as likely] to experience burnout compared to a non-musician. Heavens!

== Theory of logistic regression
<theory-of-logistic-regression>
=== Introduction
<introduction-6>
All of the concepts on the previous page bring us to the main technique of this model, which is #strong[logistic regression.] Logistic regression is used when we want to predict a #strong[binary outcome] - for example, dead/alive status, affected/unaffected status and other scenarios where we have two primary outcomes. In this sense, we are essentially making a prediction about how #emph[likely] outcome 1 is over outcome 0. Keep this in mind!

=== Modelling probabilities (sort of)
<modelling-probabilities-sort-of>
Consider the following example data. We can see that we have two columns of interest: #NormalTok("age"); and #NormalTok("outcome");. Notice how #NormalTok("outcome"); only takes the values of 0 and 1. This is because this is a #emph[binary] variable, where 0 = one outcome and 1 = another outcome. Often, we run into situations where we are interested in predicting a binary outcome using a series of predictors, including continuous ones.

#block[
#Skylighting(([#NormalTok("age_data");],));
#block[
#Skylighting(([#NormalTok("   id age outcome");],
[#NormalTok("1   1   4       0");],
[#NormalTok("2   2   5       0");],
[#NormalTok("3   3   6       0");],
[#NormalTok("4   4   7       0");],
[#NormalTok("5   5   9       0");],
[#NormalTok("6   6  12       1");],
[#NormalTok("7   7  13       1");],
[#NormalTok("8   8  14       1");],
[#NormalTok("9   9  15       1");],
[#NormalTok("10 10  16       1");],
[#NormalTok("11 11  17       1");],));
]
]
Your first thought may be to just use a simple linear regression in this instance, and sure, R isn't going to stop you from doing so:

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(");],
[#NormalTok("  ");#FunctionTok("lm");#NormalTok("(outcome ");#SpecialCharTok("~");#NormalTok(" age, ");#AttributeTok("data =");#NormalTok(" age_data)");],
[#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = outcome ~ age, data = age_data)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("     Min       1Q   Median       3Q      Max ");],
[#NormalTok("-0.36788 -0.12490  0.01528  0.13212  0.32370 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("            Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept) -0.55739    0.16515  -3.375  0.00819 ** ");],
[#NormalTok("age          0.10281    0.01421   7.235 4.89e-05 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 0.2108 on 9 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.8533,    Adjusted R-squared:  0.837 ");],
[#NormalTok("F-statistic: 52.35 on 1 and 9 DF,  p-value: 4.893e-05");],));
]
]
You might conclude that you have a significant model, with age being a significant predictor of the binary outcome. Nice! … right? Well, the moment you plot your data you may quickly see the problem with this approach:

#Skylighting(([#NormalTok("age_data ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" age, ");#AttributeTok("y =");#NormalTok(" outcome)");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_smooth");#NormalTok("(");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"lm\"");#NormalTok(", ");#AttributeTok("se =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("`geom_smooth()` using formula = 'y ~ x'");],));
]
#box(image("10-logistic_files/figure-typst/unnamed-chunk-7-1.svg"))

There are two huge problems here! For starters, the line currently implies that there are values that exist #emph[between] 0 and 1, but what is that meant to mean? In this instance, how can we have any intermediate values between our binary outcome? The second problem is that a simple linear regression also implies that there are values that exist #emph[beyond] 0 and 1, as you can hopefully see in the graph above. This also makes no sense!

=== The logistic model
<the-logistic-model>
In short, if we want to use our standard regression techniques, we need to model our data in a way where we can have outcomes beyond 0 or 1. Given that probabilities don't let us do this, that's a no-go (unless we use probit regression, but that's a different kettle of fish). Maybe we could use the odds because they let us go past 1 - but as we saw previously, odds are bounded at a minimum of 0. However… #emph[log] odds are not bounded in this way, as the log of 0 is $- oo$. It also turns out that with a large enough sample size, the relationship between a predictor and the log odds is linear. Therefore, we can model a regression against the log odds as follows:

$ l o g \( O d d s \) = beta_0 + beta_1 x_1 + epsilon.alt_i $ This is essentially the equation for logistic regression. We use the linear regression formula to predict the #emph[log odds] of an outcome. This makes logistic regression a form of the #strong[generalised linear model] (GLM). We won't go too into GLMs beyond here, but essentially the GLM uses a linear equation to model an outcome Y using a #strong[link function.] The link function describes how the predictors relate to the outcome in the model, or in other words it allows us to use a linear regression on a transformed outcome:

$ f \( Y \) = beta_0 + beta_1 x_1 + epsilon.alt_i $

In the formula above, $f \( Y \)$ is used to describe the link function. In our instance, we are looking at a #strong[logit] link to do a logistic regression, where our outcome is log odds (as opposed to Y, the dependent variable directly). There are many others out there that are suited for different types of data (e.g.~Poisson regression). As another example of a link function, the #emph[identity] function is $f \( Y \) = Y$\; this gives us linear regression, so really our usual regression models are just an example of the GLM.

The logistic function is characterised by a very obvious S-shaped curve:

#box(image("img/logistic_curve.svg"))

\(Technical note: the regression line that is fit is no longer least squares regression. Rather, it uses a procedure called #strong[maximum likelihood.] Think of it as a different engine under the hood.)

In practice, then, this means that we can use the same kinds of thinking as we have in previous regression models to interpret logistic regression outcomes. Namely, given the formula above, a 1-unit increase in $x_1$ will correspond to a $beta_1$ increase in the log odds. However, even though mathematically that makes sense, it's hard to interpret what this actually means. What does an increase in log odds correspond to??

To solve this dilemma, we often will want to convert our outcome #emph[back] into odds. To do so is simple: we simply exponentiate both sides:

$ O d d s = e^(beta_0 + beta_1 x_1 + epsilon.alt_i) $ To obtain the probability of an event occuring, we need to convert the odds back into a probability:

$ P \( Y = 1 \) = frac(1, 1 + e^(- \( beta_0 + beta_1 x_1 + epsilon.alt_i \))) $

== Example
<example-9>
Below is a dataset relating to the presence of sleep disorders (credit to Laksika Tharmalingam on #link("https://www.kaggle.com/datasets/uom190346a/sleep-health-and-lifestyle-dataset")[Kaggle] for this dataset!), and various metrics relating to lifestyle and physical health. The dataset contains the following variables:

- id: Participant id
- gender: Participant gender
- age: Participant age
- sleep\_duration: The number of hours the participant sleeps per day
- sleep\_quality: The participant's subjective rating (1-10) of the quality of their sleep
- physical\_activity: How many minutes per day the participant does physical activity
- stress: Subjective rating of stress level (1-10)
- bmi: BMI category (Underweight, normal, overweight)
- blood\_pressure: systolic/diastolic blood pressure
- heart\_rate: Resting heart rate of the participant, in bpm
- sleep\_disorder: Whether the participant has a sleep disorder or not (0 = No, 1 = Yes)

#block[
#Skylighting(([#NormalTok("sleep ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"logistic\"");#NormalTok(", ");#StringTok("\"sleep_data.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 374 Columns: 11");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (3): gender, bmi, blood_pressure");],
[#NormalTok("dbl (8): id, age, sleep_duration, sleep_quality, physical_activity, stress, ...");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
In this example, we're interested in seeing whether specific factors predict whether or not the participant has a sleep disorder. We'll work with an example with one predictor to start, and then move to multiple predictors afterwards.

=== Assumptions
<assumptions-3>
The refreshing thing about the logistic regression is that there are actually very few assumptions that need to be made. For starters, we do #strong[not] assume the following:

- Linearity between the IV and the DV
- Normality
- Homoscedasticity

None of these assumptions apply! What we do assume instead is:

- Linearity between the IV and the #emph[logit] (i.e.~the log odds)
- The outcome is a binary variable that is #emph[mutually exclusive] (someone cannot be Y = 0 and Y = 1 at the same time)
- Absence of multicollinearity (in a multiple regression context)

=== Building the model
<building-the-model>
Here is where things start to change a little from what we're used to. Because we are not building a linear model but a #emph[generalised] linear model, we now need to use the #NormalTok("glm()"); function in R. #NormalTok("glm()");, by and large, works exactly the same way as you have seen with #NormalTok("lm()");\; you need to give it arguments in the form of #NormalTok("outcome ~ predictor");, and once you have run the function you need to call the results using #NormalTok("summary()");. The first thing that changes is that by virtue of the fact that we are using the GLM, we must specify what link function we are working with. This can be set using the #NormalTok("family"); argument.

In the instance of logistic regression, the relevant family is #NormalTok("binomial");, and specifically #NormalTok("binomial(link = \"logit\")");:

#block[
#Skylighting(([#NormalTok("model ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("glm");#NormalTok("(outcome ");#SpecialCharTok("~");#NormalTok(" predictor, ");#AttributeTok("data =");#NormalTok(" data, ");#AttributeTok("family =");#NormalTok(" ");#FunctionTok("binomial");#NormalTok("(");#AttributeTok("link =");#NormalTok(" ");#StringTok("\"logit\"");#NormalTok("))");],));
]
The formula is a little strange, but #NormalTok("binomial()"); is essentially a function that takes the argument #NormalTok("link");, for which we set the value as #NormalTok("\"logit\"");. The #NormalTok("logit"); argument is the default for this function though, so we can simply shorten this down to #NormalTok("family = binomial"); specifically for logistic regressions. (For other binomial-based GLMs, you must specify the link.)

With that in mind, we can build our logistic regression models. In the first instance, let's see if age predicts whether someone has a sleep disorder.

#block[
#Skylighting(([#NormalTok("sleep_glm ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("glm");#NormalTok("(sleep_disorder ");#SpecialCharTok("~");#NormalTok(" age, ");#AttributeTok("data =");#NormalTok(" sleep, ");#AttributeTok("family =");#NormalTok(" binomial)");],
[#FunctionTok("summary");#NormalTok("(sleep_glm)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("glm(formula = sleep_disorder ~ age, family = binomial, data = sleep)");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("            Estimate Std. Error z value Pr(>|z|)    ");],
[#NormalTok("(Intercept) -5.28024    0.65343  -8.081 6.44e-16 ***");],
[#NormalTok("age          0.11549    0.01493   7.738 1.01e-14 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("(Dispersion parameter for binomial family taken to be 1)");],
[],
[#NormalTok("    Null deviance: 507.47  on 373  degrees of freedom");],
[#NormalTok("Residual deviance: 433.36  on 372  degrees of freedom");],
[#NormalTok("AIC: 437.36");],
[],
[#NormalTok("Number of Fisher Scoring iterations: 4");],));
]
]
Note that our output table is a little bit different than what we're used to; this is because of the change in procedure mentioned on the previous page (from least squares to maximum likelihood). However, we can still largely read this output the same way as we have. We can see that age is a significant predictor (#emph[p] \< .001).

The coefficient for age is .115. We can get the coefficients seperately by using the #NormalTok("coef()"); function on our model:

#block[
#Skylighting(([#FunctionTok("coef");#NormalTok("(sleep_glm)");],));
#block[
#Skylighting(([#NormalTok("(Intercept)         age ");],
[#NormalTok(" -5.2802414   0.1154897 ");],));
]
]
What does this mean? It means that for every 1 unit increase in age, the #emph[log odds] increase by .115. This is important because remember that we're modelling against #emph[log odds], not odds or probability! In essence, we have estimated the following:

$ l o g \( O d d s \) = - 5.280 + \( 0.115 times x_1 \) $

We need to make sense of this another way somehow. Recall that log odds and odds relate to each other in the following way:

$ O d d s = e^(beta_0 + beta_1 x_1 + epsilon.alt_i) $

To obtain the odds, as discussed on the previous page, we need to exponentiate our coefficients:

#block[
#Skylighting(([#FunctionTok("exp");#NormalTok("(");#FunctionTok("coef");#NormalTok("(sleep_glm))");],));
#block[
#Skylighting(([#NormalTok("(Intercept)         age ");],
[#NormalTok("0.005091201 1.122423009 ");],));
]
]
The exponentiated coefficient gives us our #strong[odds ratio.] This describes the #emph[multiplied] change in odds for every 1 unit increase of our predictor. In this instance, for every 1 year increase in age, the predicted odds of having a sleep disorder are multiplied by 1.12. Another way to describe this is that the predicted odds of having a sleep disorder increase by a #emph[factor of] 1.12.

This coefficient does #emph[not] mean the following:

- The odds increase by 1.12 for every unit of x - remember, only the #emph[log odds] are linearly related to the predictor. The odds are non-linearly related.
- The probability increases by 1.12 - same deal as above, the probability isn't linearly related to the predictors.

We can get confidence intervals around our estimated coefficients using #NormalTok("confint()");, just like we have previously. We can do this either on the original coefficients, or the exponentiated ones. The confidence interval around the exponentiated coefficients gives us a 95% CI for our odds ratio.This is probably more useful in terms of interpretation than the log odds coefficients, so we have chosen them here.

#block[
#Skylighting(([#FunctionTok("confint");#NormalTok("(sleep_glm)");],));
#block[
#Skylighting(([#NormalTok("Waiting for profiling to be done...");],));
]
#block[
#Skylighting(([#NormalTok("                  2.5 %     97.5 %");],
[#NormalTok("(Intercept) -6.60646431 -4.0395789");],
[#NormalTok("age          0.08712071  0.1457569");],));
]
]
#block[
#Skylighting(([#FunctionTok("exp");#NormalTok("(");#FunctionTok("confint");#NormalTok("(sleep_glm))");],));
#block[
#Skylighting(([#NormalTok("Waiting for profiling to be done...");],));
]
#block[
#Skylighting(([#NormalTok("                  2.5 %     97.5 %");],
[#NormalTok("(Intercept) 0.001351603 0.01760488");],
[#NormalTok("age         1.091028365 1.15691494");],));
]
]
Thus, we can say that the OR of a sleep disorder is 1.12 (95% CI = \[1.09, 1.16\]).

=== Predictions
<predictions-1>
Now recall that we can convert from odds to probabilities in the following manner:

$ P \( Y = 1 \) = frac(1, 1 + e^(- \( beta_0 + beta_1 x_1 + epsilon.alt_i \))) $

Using this, we can make predictions about the #emph[probability] of our outcome for a given value of our predictor. For example, what is the probability that a 50 year old will have a sleep disorder? That would be given as the following:

$ P \( Y = 1 \) = frac(1, 1 + e^(- \( beta_0 + beta_1 x_1 + epsilon.alt_i \))) $

$ P \( Y = 1 \) = frac(1, 1 + e^(- \( - 5.280 + \( 0.115 times 50 \))) $

$ P \( Y = 1 \) = frac(1, 1 + e^(- 0.47)) $

We can use R to do the calculation for us:

#block[
#Skylighting(([#DecValTok("1");#SpecialCharTok("/");#NormalTok("(");#DecValTok("1");#NormalTok(" ");#SpecialCharTok("+");#NormalTok(" ");#FunctionTok("exp");#NormalTok("(");#SpecialCharTok("-");#FloatTok("0.47");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("[1] 0.6153838");],));
]
]
Thus, a 50 year old person has a 61.5% chance of having a sleep disorder (note that this has been rounded).

We can actually plot the expected probabilities across a range of values for age by first asking R to predict the probabilities across a range of ages. This will draw the characteristic S-shaped curve of the logistic model. We use the #NormalTok("predict()"); function to calculate the predicted probabilities of each value of our predictor. The #NormalTok("type = response"); argument is used here to tell R to predict the probabilities (and not the log odds).

#block[
#Skylighting(([#NormalTok("`geom_smooth()` using formula = 'y ~ x'");],));
]
#block[
#Skylighting(([#NormalTok("Warning in eval(family$initialize): non-integer #successes in a binomial glm!");],));
]
#box(image("10-logistic_files/figure-typst/unnamed-chunk-17-1.svg"))

=== Logistic regression with multiple predictors
<logistic-regression-with-multiple-predictors>
Let's now expand out the previous example to include two predictors: age and stress. Just like a regular multiple regression, logistic regression can include multiple continuous predictors. This will take on the form of the following:

$ l o g \( O d d s \) = beta_0 + beta_1 x_1 + beta_2 x_2 . . . beta_n x_n + epsilon.alt_i $

This means that our odds formula becomes:

$ O d d s = e^(beta_0 + beta_1 x_1 + beta_2 x_2 . . . beta_n x_n + epsilon.alt_i) $ And so on so forth with our probability formula. Really, this is just an extension of what we have already seen in multiple regression, but applied to a logistic regression context. Let's see what this looks like in R with the below code:

#block[
#Skylighting(([#NormalTok("sleep_glm2 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("glm");#NormalTok("(sleep_disorder ");#SpecialCharTok("~");#NormalTok(" age ");#SpecialCharTok("+");#NormalTok(" stress, ");#AttributeTok("data =");#NormalTok(" sleep, ");#AttributeTok("family =");#NormalTok(" binomial)");],
[#FunctionTok("summary");#NormalTok("(sleep_glm2)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("glm(formula = sleep_disorder ~ age + stress, family = binomial, ");],
[#NormalTok("    data = sleep)");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("             Estimate Std. Error z value Pr(>|z|)    ");],
[#NormalTok("(Intercept) -13.26171    1.41932  -9.344  < 2e-16 ***");],
[#NormalTok("age           0.20510    0.02212   9.272  < 2e-16 ***");],
[#NormalTok("stress        0.77585    0.10607   7.315 2.58e-13 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("(Dispersion parameter for binomial family taken to be 1)");],
[],
[#NormalTok("    Null deviance: 507.47  on 373  degrees of freedom");],
[#NormalTok("Residual deviance: 355.62  on 371  degrees of freedom");],
[#NormalTok("AIC: 361.62");],
[],
[#NormalTok("Number of Fisher Scoring iterations: 5");],));
]
]
What do we see here? Well, we can see that age is a significant predictor of the presence of a sleep disorder (#emph[p] \< .001), and stress is as well (#emph[p] \< .001). Namely, for every year increase in age, the log odds of a sleep disorder increase by 0.205, holding stress constant. Likewise, for every 1 point increase in stress, the log odds increase by .776, holding age constant.

To convert this into odds ratios, we exponentiate the coefficients:

#block[
#Skylighting(([#FunctionTok("exp");#NormalTok("(");#FunctionTok("coef");#NormalTok("(sleep_glm2))");],));
#block[
#Skylighting(([#NormalTok(" (Intercept)          age       stress ");],
[#NormalTok("1.739856e-06 1.227649e+00 2.172449e+00 ");],));
]
]
And let's generate confidence intervals for our odds ratios too:

#block[
#Skylighting(([#FunctionTok("exp");#NormalTok("(");#FunctionTok("confint");#NormalTok("(sleep_glm2))");],));
#block[
#Skylighting(([#NormalTok("Waiting for profiling to be done...");],));
]
#block[
#Skylighting(([#NormalTok("                   2.5 %       97.5 %");],
[#NormalTok("(Intercept) 9.083049e-08 0.0000240461");],
[#NormalTok("age         1.178095e+00 1.2851325926");],
[#NormalTok("stress      1.782252e+00 2.7038110976");],));
]
]
We can see that the for every 1 year increase in age, the predicted odds of having a sleep disorder increase by a factor (i.e.~are multiplied by) of 1.23 (95% CI: \[1.18, 1.29\]), holding stress constant. For every 1 unit increase in stress, the predicted odds of a sleep disorder increase by a factor of 2.17 (95% CI: \[1.78, 2.70\]), holding age constant.

Just like before, we can also predict the probability that a participant will have a sleep disorder given their age and stress level. For example, let's say we have a 50 year old with a stress level of 5:

$ P \( Y = 1 \) = frac(1, 1 + e^(- \( - 13.262 + \( 0.205 times 50 \) + \( 0.776 times 5 \) \))) $

$ P \( Y = 1 \) = frac(1, 1 + e^(- 0.868)) = 0.704 $

THus, this individual has a 70.4% chance of having a sleep disorder. Now what about if the person's stress level is 6?

$ P \( Y = 1 \) = frac(1, 1 + e^(- \( - 13.262 + \( 0.205 times 50 \) + \( 0.776 times 6 \) \))) $

$ P \( Y = 1 \) = frac(1, 1 + e^(- 1.644)) = 0.838 $ Now the person's probability is 83.8%. In other words, it helps not to be stressed!

== Pseudo $R^2$
<pseudo-r2>
=== Regular $R^2$
<regular-r2>
Recall that in a linear regression, we often talk about $R^2$, or the coefficient of determination. We interpret this value as the amount of variance that is explained in our outcome by our predictor in the regression (or all of our predictors, in the case of multiple regression).

As a reminder, here is the output for the regression on flow proneness in #link(<multreg-intro>)[the regression module]:

#block[
#Skylighting(([#NormalTok("w10_flow_lm ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(DFS_Total ");#SpecialCharTok("~");#NormalTok(" trait_anxiety ");#SpecialCharTok("+");#NormalTok(" openness, ");#AttributeTok("data =");#NormalTok(" w10_flow)");],
[#FunctionTok("summary");#NormalTok("(w10_flow_lm)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = DFS_Total ~ trait_anxiety + openness, data = w10_flow)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("    Min      1Q  Median      3Q     Max ");],
[#NormalTok("-16.596  -2.331  -0.151   2.308  12.794 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("              Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)   32.65078    1.13377  28.798  < 2e-16 ***");],
[#NormalTok("trait_anxiety -0.11116    0.01278  -8.697  < 2e-16 ***");],
[#NormalTok("openness       0.83372    0.14538   5.735 1.38e-08 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 3.705 on 808 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.1364,    Adjusted R-squared:  0.1343 ");],
[#NormalTok("F-statistic: 63.81 on 2 and 808 DF,  p-value: < 2.2e-16");],));
]
]
As we can see, our value for $R^2$ is .1364, meaning that 13.64% of the variance in our outcome, flow proneness, can be explained by our predictors trait anxiety and openness. The mathematical properties of least squares regression allow us to derive this value and interpret it fairly cleanly and easily. We can even compare $R^2$ across similar models, or (in the hierarchical case) use it to directly compare model fit.

In logistic regression, however, we cannot calculate the same value as we no longer use ordinary least squares regression. Instead, we use #strong[maximum likelihood], which provides a different way of calculating the various parameters (i.e.~coefficients) in our model. Maximum likelihood methods in the context of logistic regression don't really give us the same 'clean' and easily interpretable $R^2$ as we get in normal regressions, because we don't operate under the same method of minimising residuals. Rather, these $R^2$ methods are calculated using each model's likelihood, $hat(L)$.

To partially overcome this, several measures of #strong[pseudo $R^2$] have been developed. The word 'pseudo' is important here, as it's important to acknowledge that these are not quite the same thing as our usual $R^2$. We can't use them in the same way to directly compare across models, for instance - each pseudo-$R^2$ has its own suggested interpretation, and thus do not always cohere with each other. The wonderful #link("https://stats.oarc.ucla.edu/other/mult-pkg/faq/general/faq-what-are-pseudo-r-squareds/")[Statistical Methods and Data Analysis group] at UCLA have a great explanation, with formulae for several pseudo-$R^2$ measures. We will focus on three in this module, mainly for parity with Jamovi (but they also happen to be the most popular).

=== Calculating pseudo-$R^2$ measures
<calculating-pseudo-r2-measures>
As a reminder, let's print the output from our logistic regression on sleep:

#block[
#Skylighting(([#FunctionTok("summary");#NormalTok("(sleep_glm)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("glm(formula = sleep_disorder ~ age, family = binomial, data = sleep)");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("            Estimate Std. Error z value Pr(>|z|)    ");],
[#NormalTok("(Intercept) -5.28024    0.65343  -8.081 6.44e-16 ***");],
[#NormalTok("age          0.11549    0.01493   7.738 1.01e-14 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("(Dispersion parameter for binomial family taken to be 1)");],
[],
[#NormalTok("    Null deviance: 507.47  on 373  degrees of freedom");],
[#NormalTok("Residual deviance: 433.36  on 372  degrees of freedom");],
[#NormalTok("AIC: 437.36");],
[],
[#NormalTok("Number of Fisher Scoring iterations: 4");],));
]
]
The #NormalTok("DescTools"); package provides a very convenient function, #NormalTok("PseudoR2()");, to calculate these pseudo-$R^2$ measures for us. This function requires a) the name of the #NormalTok("glm"); model (i.e.~our logistic regression object), and b) a character specifying which type(s) of $R^2$ should be calculated. You'll see this in the examples below.

#strong[McFadden's $R^2$] is roughly analogous to a regular $R^2$, in that it is intended to give an estimate of how much total variability is explained by the logistic model. It is calculated by comparing the fit of a logistic model against a null (i.e.~no predictor) model.

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(DescTools)");],
[#FunctionTok("PseudoR2");#NormalTok("(sleep_glm, ");#AttributeTok("which =");#NormalTok(" ");#StringTok("\"McFadden\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok(" McFadden ");],
[#NormalTok("0.1460373 ");],));
]
]
#strong[Cox and Snell's $R^2$] is also calculated by comparing a full model to an null/no predictor model. The underlying calculation, however, is different, and a particular oddity of the Cox and Snell $R^2$ is that the maximum possible value is less than 1.

#block[
#Skylighting(([#FunctionTok("PseudoR2");#NormalTok("(sleep_glm, ");#AttributeTok("which =");#NormalTok(" ");#StringTok("\"CoxSnell\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok(" CoxSnell ");],
[#NormalTok("0.1797558 ");],));
]
]
#strong[Nagelkerke's $R^2$] is an adjustment of the Cox and Snell $R^2$ - specifically, it adjusts the value of $R^2$ so that it ranges from 0-1.

#block[
#Skylighting(([#FunctionTok("PseudoR2");#NormalTok("(sleep_glm, ");#AttributeTok("which =");#NormalTok(" ");#StringTok("\"Nagelkerke\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Nagelkerke ");],
[#NormalTok(" 0.2420843 ");],));
]
]
Finally, #strong[Tjur's $R^2$] is a relatively new pseudo-$R^2$. It is calculated by first calculating the average predicted probabilities of the outcomes, and then taking the differences between those two probabilities. It is bounded between 0-1 and is also roughly analogous to a normal $R^2$.

#block[
#Skylighting(([#FunctionTok("PseudoR2");#NormalTok("(sleep_glm, ");#AttributeTok("which =");#NormalTok(" ");#StringTok("\"Tjur\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("     Tjur ");],
[#NormalTok("0.1888425 ");],));
]
]
=== When do you report it?
<when-do-you-report-it>
Truthfully, as the UCLA help page states, pseudo-$R^2$ methods are not as useful or as cleanly interpretable as normal OLS-based $R^2$. They are only useful when comparing models using the #emph[same] pseudo-$R^2$ value, using the same data and variables. In other words, these measures are useful to select between competing models on the same data; they are not valid for comparing across datasets.

Another thing to consider is that different measures perform differently. Simulation studies (e.g.~Veall and Zimmermann 1992) have shown that Nagelkerke and McFadden's $R^2$ both severely underestimate the 'true' value of $R^2$. Other methods exist, which can be calculated with #NormalTok("PseudoR2()");, but are not as widely implemented.

Some will argue that $R^2$ values are pointless outside of the model selection context. Others will say that it never hurts to report them anyway even if you are reporting just the one model. The decision, ultimately, is probably best left to you as the researcher to figure out what is most appropriate for what you are doing.

= Exploratory factor analysis
<exploratory-factor-analysis>
Many of the #emph[things] we are interested in psychological research are things that are both #emph[unobservable] and not #emph[directly] measurable. Consider, for instance, someone's height: this is an observable and directly measurable quantity, in that we can a) see how tall they are and b) take a tape measure to them and get a direct, precise measurement of their height. In contrast, consider the things that we are often interested in when it comes to psychological constructs: motivations, wellbeing attitudes, beliefs, cognitive abilities, values, personality features…

None of these kinds of constructs are directly measurable or even tangible. We can't take a rule to measure how much someone enjoys listening to music, for example, or identify the extent to which they believe that listening to certain genres is healthy or unhealthy for you. However, we might be able to observe #emph[behaviours] that might relate to these constructs, or people may respond to questions in ways that are indicative of said constructs.

In this module we talk about #strong[factor analysis], which is one method of using statistics to identify these #strong[latent constructs]. Specifically, we will focus on #strong[exploratory factor analysis], which aims to take a series of variables and identify the latent constructs that may underlie these variables.

== Introduction to EFA
<introduction-to-efa>
We generally conduct a survey because we're interested in how different people hold different attitudes, ideas or beliefs about things. All of the standard statistical tools that you learned in Modules 5 and 6 are useful in this regard, and can absolutely be used with survey data. But given how highly dimensional survey data is, it opens up a new way of analysing data - exploratory factor analysis.

=== Dimension reduction
<dimension-reduction>
Sometimes it's easy to forget that designing a questionnaire and administering it gives rise to quite complex data. After all, a single question item may simply ask participants to rate themselves on a statement using a Likert scale, as we have seen earlier in this module. However, consider how many questions we might collect across a scale and it quickly becomes evident that this kind of data is highly dimensional - that is, with lots of individual questions we end up with a lot of data to sift through.

This kind of scenario is where dimension reduction techniques become extremely useful. Dimension reduction techniques allow us to essentially collapse data into 'supervariables' that can simplify the analyses that we do by capturing the commonalities across questionnaire items.

Principal components analysis (PCA) is the most common form of dimension reduction. Principal components analysis lets us take highly dimensional data, such as a questionnaire/scale with multiple items, and collapse that down into a smaller number of components.

=== Factor analysis
<factor-analysis>
Factor analysis is another analytical technique like dimension reduction. However, the key conceptual difference is that while PCA lets us collapse multiple variables into a smaller number of components, factor analysis lets us identify latent factors in our data. Latent factors are the factors underlying the behaviours and responses that we observe in our questionnaire items. We might find, for example, that performance on a series of tests is actually underlaid by multiple distinct, theoretically meaningful factors.

Therefore, factor analysis lets us build and test theories about latent psychological constructs. Factor analysis allows us to indirectly measure these latent factors - essentially, are our questions tapping into the same 'thing'?

Factor analysis can be split into exploratory factor analysis (EFA) and confirmatory factor analysis (CFA). We will focus specifically on EFA in this module.

#strong[A terminology note]

You'll note that we've described PCA as generating components, while FA generates factors. It's worth remembering that this is intentional, and the two terms should not be used interchangeably. We will talk more about this on the pages that follow, but components are simply linear combinations of multiple variables. Factors are estimates of latent variables that drive behaviour. The latter specifically is what we use to test theories about psychological constructs.

=== The steps of exploratory factor analysis
<the-steps-of-exploratory-factor-analysis>
EFA is quite an involved analysis, and there are several considerations that must be taken into account:

- Prepare data and assess for suitability
- Decide on the extraction method
- Decide on how many factors to retain
- Decide on the rotation method
- Interpret the results

=== Example dataset
<example-dataset>
The example we'll be using to work through this data is from a brilliant statistician and educator, Professor Andy Field, who is very highly regarded for his Discovering Statistics series - including Discovering Statistics with SPSS and Discovering Statistics with R. I highly recommend checking them out if you plan on using them!

As part of his book, Prof.~Field came up with a questionnaire called the SPSS Anxiety Questionnaire (SAQ). For the purposes of the next few pages we'll be using a reduced version with just 9 questions, which we'll call the SAQ-9. The questions in this survey are:

Q1: Statistics makes me cry Q2: My friends will think I'm stupid for not being able to cope with SPSS Q4: I dream that Pearson is attacking me with correlation coefficients Q5: I don't understand statistics Q6: I have little experience of computers Q14: Computers have minds of their own and deliberately go wrong whenever I use them Q15: Computers are out to get me Q19: Everybody looks at me when I use SPSS Q22: My friends are better at SPSS than I am

#block[
#Skylighting(([#NormalTok("saq ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"efa\"");#NormalTok(", ");#StringTok("\"SAQ-9.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 2571 Columns: 9");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("dbl (9): q01, q02, q04, q05, q06, q14, q15, q19, q22");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
As we walk through the content, we will use this dataset to illustrate how to conduct an exploratory factor analysis. (Note the questions were specifically chosen for demonstration purposes.)

To actually conduct the EFA, we will primarily rely on two packages: #NormalTok("psych"); and #NormalTok("EFA.dimensions");. The #NormalTok("psych"); package is a fairly big package designed to run many common analyses in psychological science, specifically analyses that relate to #emph[psychometrics.] It's an incredibly useful package to be aware of in general. #NormalTok("EFA.dimensions"); is another great package that provides functions to help with certain parts of the EFA process.

== Theory of EFA
<theory-of-efa>
On this page, we (briefly) touch on a bit of the statistical theory underlying factor analysis and PCA. We won't dive too deeply into the maths underlying EFA, but will focus on the high-level conceptual stuff.

=== PCA vs EFA
<pca-vs-efa>
Here is a good point to formally differentiate PCA vs EFA, following on from the brief disclaimer on the previous page.

Both PCA and EFA will extract up to k factors that attempt to explain the observed variables. k, in this instance, is capped at the number of observed variables; so, if you input 24 variables into a PCA, the maximum number of components that you can estimate is 24. However, what defines these components/factors differs:

- In PCA, where we are just interested in collapsing variables, we assume that all variance in the observed variables is explained by the factors. Ultimately, a PCA will extract k components that ultimately explain 100% of the variance in all of the observed variables.
- In EFA, the goal is only to explain common variance between the observed variables. EFA explicitly models the variance in the items to be comprised of common variance, which is variance due to shared underlying factors, and unique variance. Unique variance can be further broken down into specific variance, which is variance that is specific to each item, and error variance. By partitioning variance in this way, EFA is able to test models of factors as it allows for disconfirmation - a vital part of any model testing.

In short, EFA allows us to generate theoretical entities that we can test in subsequent analyses. PCA only provides us with a measure that combines the effects of multiple variables, but does not test latent factors.

=== The common factor model
<the-common-factor-model>
The basis of factor analysis is the common factor model. Broadly speaking, the common factor model suggests that variables that relate to each other are likely driven by underlying latent variables. For example, if five questions in a survey all ask about a specific aspect of motivation, and these items correlate with each other, we would expect the same thing - or latent factor - to be driving responses on these five items. Exploratory factor analysis operates under this common factor model.

Below is a basic diagram of the common factor model. The squares represent observed variables, which are the variables that we measure. The big circle denotes the latent factor that we want to estimate. The circles leading to the observed variables are error terms. In an exploratory factor analysis, the primary thing we want to investigate is the factor loadings, denoted by the various lambdas ($lambda$). We will see precisely what the factor loadings are later, but generally they are how strongly the latent factor predicts each observed variable.

#box(image("img/common_factor_1.svg"))

Now let's take a look at the common factor model with two factors. As you can see, we allow every observed variable to load onto every factor - thus, we estimate factor loadings for every possible path going from latent factors to observed variables. This is what we estimate in exploratory factor analysis (and PCA - sort of).

For brevity's sake, only three lambdas have been shown, but hopefully they are illustrative enough to get the general gist across. Every path leading from a latent variable to an observed variable is a parameter to be estimated in an exploratory factor analysis.

#box(image("img/common_factor_2.svg"))

=== Partial correlations
<partial-correlations-2>
In Module 10, we talked about the concept of #strong[correlation] - i.e.~how related two variables are. Recall that correlation coefficients are scaled from -1 to 1. In Extension Module 3 we also talked about the concept of #strong[partial correlation] - the relationship between two variables while controlling for a third, as denoted using the below formula:

$ r_(x y . z) = frac(r_(x y) - \( r_(x z) times r_(y z) \), sqrt(\( 1 - r_(x z)^2 \) \( 1 - r_(y z)^2 \))) $

Both PCA and EFA rely on estimating partial correlations. Specifically, factor analysis aims to estimate latent factors that #strong[minimise the partial correlations] among #strong[observed] variables. If a latent factor perfectly explains the relationship between two variables, the partial correlations between the observed variables should be zero. A lot of the 'under the hood' maths, which we won't touch on, essentially relates to identifying the latent factors that maximise the #strong[amount of variance] explained in each variable by the factor solutions.

== Initial considerations for EFA
<initial-considerations-for-efa>
We'll start with some basic considerations for EFA/PCA. These are generally things that should be thought about/considered before an EFA, or at least before you interpret the results.

=== Sample size
<sample-size>
For adequate power, EFA typically needs a fairly big sample size. There is no clear agreement about what constitutes a 'good' sample size, and it's difficult to give concrete recommendations.

Many guides and sources will often mention a n:p rule of thumb, where n is sample size and p is number of variables (which is the number of parameters that needs to be estimated). The idea is that an ideal EFA sample size will have n participants for every variable you are analysing. These can range from as low as 3:1 to 20:1, with a typical 'ok' range being from 10-20:1. However, there is no clear support for these rules, and no minimum is truly sufficient (Hogarty et al.~2005).

In general - the bigger the better, and the more variables you have the more participants you need. Aim for at least 300+ no matter the circumstance (this is a very blunt rule of thumb!).

Below are our descriptives. While we can use a bit of tidyverse to get descriptives, the #NormalTok("describe()"); function from the #NormalTok("psych"); package is also convenient for getting basic descriptives for every column in a dataset. We can see that we have n = 2571, which should be more than adequate.

#block[
#Skylighting(([#FunctionTok("describe");#NormalTok("(saq)");],));
#block[
#Skylighting(([#NormalTok("    vars    n mean   sd median trimmed  mad min max range  skew kurtosis   se");],
[#NormalTok("q01    1 2571 2.37 0.83      2    2.34 0.00   1   5     4  0.65     0.61 0.02");],
[#NormalTok("q02    2 2571 1.62 0.85      1    1.46 0.00   1   5     4  1.49     2.04 0.02");],
[#NormalTok("q04    3 2571 2.79 0.95      3    2.74 1.48   1   5     4  0.39    -0.29 0.02");],
[#NormalTok("q05    4 2571 2.72 0.96      3    2.68 1.48   1   5     4  0.46    -0.44 0.02");],
[#NormalTok("q06    5 2571 2.23 1.12      2    2.09 1.48   1   5     4  0.93     0.15 0.02");],
[#NormalTok("q14    6 2571 2.88 1.00      3    2.84 1.48   1   5     4  0.29    -0.36 0.02");],
[#NormalTok("q15    7 2571 2.77 1.01      3    2.72 1.48   1   5     4  0.43    -0.45 0.02");],
[#NormalTok("q19    8 2571 2.29 1.10      2    2.21 1.48   1   5     4  0.48    -0.72 0.02");],
[#NormalTok("q22    9 2571 2.89 1.04      3    2.93 1.48   1   5     4 -0.07    -0.68 0.02");],));
]
]
=== Assumptions
<assumptions-4>
EFA can be conducted with one of multiple algorithms that determines the final factor structure to be extracted. Different methods rely on different assumptions, so basic assumption checks are useful:

- Data must be interval/ratio data. Ordinal data is problematic unless you generally have at least 5 scale points; in which case, you can broadly approximate this to be continuous.
- Normality is important, depending on the method. The usual QQ-plot or Shapiro-Wilks tests on individual items can be useful here.
- Multicollinearity: observed variables should not be collinear with each other.

Note though that the Shapiro-Wilks test only tests the normality of one variable, i.e.~univariate normality. EFA is ideal with multivariate normality, i.e.~the joint dimensions of the entire dataset are normally distributed. Univariate normality is necessary but not sufficient for multivariate normality. Although Jamovi doesn't provide an easy way to test for multivariate normality (yet), it is very easy to do so in R with the #NormalTok("MVN"); package.

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(MVN)");],
[],
[#CommentTok("# Use the mvn() function to create the test output");],
[#NormalTok("mvn_results ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("mvn");#NormalTok("(saq, ");#AttributeTok("mvn_test =");#NormalTok(" ");#StringTok("\"mardia\"");#NormalTok(")");],
[],
[#CommentTok("# Extract the multivariate normality test only");],
[#NormalTok("mvn_results");#SpecialCharTok("$");#NormalTok("multivariate_normality");],));
#block[
#Skylighting(([#NormalTok("             Test Statistic p.value     Method          MVN");],
[#NormalTok("1 Mardia Skewness  2300.558  <0.001 asymptotic ✗ Not normal");],
[#NormalTok("2 Mardia Kurtosis    23.632  <0.001 asymptotic ✗ Not normal");],));
]
]
=== Factorability
<factorability>
Factorability broadly describes whether the data are likely to be amenable to factor analysis. If data are factorable, it suggests that there is likely to be at least one latent factor underlying the observations.

We can test factorability in three ways:

+ Correlations

A simple matrix of correlations can give us a first-pass indication of factorability. If most items correlate with each other, this can indicate that there are underlying latent factors. There is no hard and fast rule for what counts as 'acceptable', but if most variables are not significantly correlated that indicates that the data may not be factorable. In our SAQ-9 data, we can see that all correlations between variables are significant, which is generally a good sign.

#block[
#Skylighting(([#FunctionTok("cor");#NormalTok("(saq)");],));
#block[
#Skylighting(([#NormalTok("            q01         q02         q04        q05         q06        q14");],
[#NormalTok("q01  1.00000000 -0.09872403  0.43586018  0.4024399  0.21673399  0.3378797");],
[#NormalTok("q02 -0.09872403  1.00000000 -0.11185965 -0.1193466 -0.07420968 -0.1646999");],
[#NormalTok("q04  0.43586018 -0.11185965  1.00000000  0.4006722  0.27820154  0.3508096");],
[#NormalTok("q05  0.40243992 -0.11934658  0.40067225  1.0000000  0.25746014  0.3153381");],
[#NormalTok("q06  0.21673399 -0.07420968  0.27820154  0.2574601  1.00000000  0.4022441");],
[#NormalTok("q14  0.33787966 -0.16469991  0.35080964  0.3153381  0.40224407  1.0000000");],
[#NormalTok("q15  0.24575263 -0.16499581  0.33423089  0.2613719  0.35989309  0.3801148");],
[#NormalTok("q19 -0.18901103  0.20329748 -0.18597751 -0.1653221 -0.16675017 -0.2540581");],
[#NormalTok("q22 -0.10440866  0.23087487 -0.09838349 -0.1325359 -0.16513541 -0.1698375");],
[#NormalTok("           q15        q19         q22");],
[#NormalTok("q01  0.2457526 -0.1890110 -0.10440866");],
[#NormalTok("q02 -0.1649958  0.2032975  0.23087487");],
[#NormalTok("q04  0.3342309 -0.1859775 -0.09838349");],
[#NormalTok("q05  0.2613719 -0.1653221 -0.13253593");],
[#NormalTok("q06  0.3598931 -0.1667502 -0.16513541");],
[#NormalTok("q14  0.3801148 -0.2540581 -0.16983754");],
[#NormalTok("q15  1.0000000 -0.2098023 -0.16790617");],
[#NormalTok("q19 -0.2098023  1.0000000  0.23392259");],
[#NormalTok("q22 -0.1679062  0.2339226  1.00000000");],));
]
#Skylighting(([#CommentTok("# Alternatively, the lowerCor() fucntion from psych prints this more nicely");],
[],
[#FunctionTok("lowerCor");#NormalTok("(saq)");],));
#block[
#Skylighting(([#NormalTok("    q01   q02   q04   q05   q06   q14   q15   q19   q22  ");],
[#NormalTok("q01  1.00                                                ");],
[#NormalTok("q02 -0.10  1.00                                          ");],
[#NormalTok("q04  0.44 -0.11  1.00                                    ");],
[#NormalTok("q05  0.40 -0.12  0.40  1.00                              ");],
[#NormalTok("q06  0.22 -0.07  0.28  0.26  1.00                        ");],
[#NormalTok("q14  0.34 -0.16  0.35  0.32  0.40  1.00                  ");],
[#NormalTok("q15  0.25 -0.16  0.33  0.26  0.36  0.38  1.00            ");],
[#NormalTok("q19 -0.19  0.20 -0.19 -0.17 -0.17 -0.25 -0.21  1.00      ");],
[#NormalTok("q22 -0.10  0.23 -0.10 -0.13 -0.17 -0.17 -0.17  0.23  1.00");],));
]
]
#block[
#set enum(numbering: "1.", start: 2)
+ Bartlett's test of sphericity
]

Bartlett's test of sphericity tests the null hypothesis that all correlations between variables are zero at the population level. In other words, if Bartlett's test is non-significant it suggests that all of the indicator variables are not correlated. As a result, Bartlett's test is pretty much always significant as it is very sensitive to sample size. Unsurprisingly, then, our Bartlett's test result is significant.

To run this, we use the #NormalTok("cortest.bartlett()"); function from #NormalTok("psych");. Note that base R does include a function called #NormalTok("bartlett.test()");, but this is not the same test! (same Bartlett, though.)

#block[
#Skylighting(([#FunctionTok("cortest.bartlett");#NormalTok("(saq)");],));
#block[
#Skylighting(([#NormalTok("R was not square, finding R from data");],));
]
#block[
#Skylighting(([#NormalTok("$chisq");],
[#NormalTok("[1] 3674.737");],
[],
[#NormalTok("$p.value");],
[#NormalTok("[1] 0");],
[],
[#NormalTok("$df");],
[#NormalTok("[1] 36");],));
]
]
#block[
#set enum(numbering: "1.", start: 3)
+ Kaiser-Meyer-Olkin (KMO) Test/Kaiser's Measure of Sampling Adequacy
]

This test is often referred to as the KMO Test or Kaiser's MSA, but both respectively mean the same thing. It is a measure of how much variance among all variables might be due to common variance. Higher KMO/MSA values indicate that more variance is likely due to common factors, thus indicating suitability for factor analysis.

Kaiser (1974) provided the following (hilarious) interpretations of MSA values:

#table(
  columns: 2,
  align: (left,left,),
  table.header([MSA value], [Interpretation],),
  table.hline(),
  [MSA between .80 - .90], [Marvelous],
  [MSA between .70 - .80], [Middling],
  [MSA between .60 - .70], [Mediocre],
  [NSA between .50 - .60], [Miserable],
  [MSA \< .50], [Unacceptable],
)
MSA values are typically calculated for each variable, and for overall. It helps to report both. The #NormalTok("KMO()"); function in #NormalTok("psych"); will calculate both sets of measures of sampling adequacy. Here are our variables below. Overall they are generally in the meritorious range (except for one):

#block[
#Skylighting(([#FunctionTok("KMO");#NormalTok("(saq)");],));
#block[
#Skylighting(([#NormalTok("Kaiser-Meyer-Olkin factor adequacy");],
[#NormalTok("Call: KMO(r = saq)");],
[#NormalTok("Overall MSA =  0.82");],
[#NormalTok("MSA for each item = ");],
[#NormalTok(" q01  q02  q04  q05  q06  q14  q15  q19  q22 ");],
[#NormalTok("0.81 0.76 0.82 0.84 0.82 0.84 0.85 0.84 0.77 ");],));
]
]
== How many factors/components?
<how-many-factorscomponents>
A crucial element of doing an EFA is deciding on the number of factors that should be extracted for the final solution. This is not a trivial decision, and essentially determines the final factor structure you derive and interpret in your factor analysis. Note that while we mainly talk about factors on this page, the same considerations apply when thinking of components in PCA.

=== Deciding on the number of factors
<deciding-on-the-number-of-factors>
Recall that an EFA/PCA will extract up to k factors/components, where k is the number of observed variables. At k factors/components, this will have explained all of the possible variance there is to explain in the observed variables. The basic idea behind how these factors are calculated is by essentially drawing straight lines through our data, much like a regression line. The idea is that each straight line (factor/component) should explain as much variance as possible, and each successive factor/component that is drawn explains the remaining variance.

The first factor/component will always attempt to explain the most variance possible. The second factor/component will then be drawn through what remains after the first factor/component is calculated, in a way that both maximises the variance captured and is uncorrelated with the first factor/component. This lets us capture as much variance as possible in a clean way, where we can identify the relative contributions of each successive factor/component.

The amount of variance that is captured by each factor/component is represented by a number called the #strong[eigenvalue.] Naturally, the first factor/component will have the highest eigenvalue, and the eigenvalue of each factor/component afterwards will decrease.

This means that at some point, we reach a stage where an additional factor doesn't add much in terms of the variance explained. This indicates that there isn't much utility in retaining factors after a certain point - i.e.~we get diminishing returns on increasing the number of factors we have to interpret. We must strike a balance between having a relatively straightforward factor structure to interpret and how much variance is explained. Too few factors means we may not accurately capture enough variance to be meaningful or miss very crucial relationships, but too many factors means we lose parsimony and interpretability.

There are several ways in which we can identify where the most optimal number of factors to retain is.

=== The Kaiser-Guttman rule
<the-kaiser-guttman-rule>
The Kaiser-Guttman, Kaiser or simply the "eigenvalue \> 1" rule states that we should simply keep any factor with an eigenvalue above 1. To do this, we first need a correlation matrix from our data. We then feed this to the #NormalTok("eigen()"); function in base R, which will calculate eigenvalues. I've piped it here, but you can also go straight to #NormalTok("eigen(cor(saq))");. Our data suggests that we retain 2 factors using this rule.

#block[
#Skylighting(([#NormalTok("saq_eigen ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cor");#NormalTok("(saq) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("eigen");#NormalTok("()");],
[],
[#NormalTok("saq_eigen");#SpecialCharTok("$");#NormalTok("values");],));
#block[
#Skylighting(([#NormalTok("[1] 2.9515869 1.2029159 0.9339932 0.7897083 0.7671243 0.6453702 0.6078335");],
[#NormalTok("[8] 0.5663971 0.5350707");],));
]
]
=== The scree plot
<the-scree-plot>
The scree plot is a plot of each factor's eigenvalue. This method relies on visual inspection - namely, you want to identify the 'elbow' of the line, or the point where the graph levels off. This is the point where the amount of variance explained by additional factors reaches that diminishing returns phase.

#NormalTok("psych"); will plot two sets of eigenvalues - one 'component'-based set (which is what we calculated above), and one 'factor'-based set (which is what Jamovi gives you).

This is inherently a bit subjective, and sometimes isn't very clear. On our scree plot below, it looks like four factors is the point where the diminishing returns begin, so we would go with retaining four factors. However, a more conservative interpreter could reasonably argue that we should only retain 2 factors.

#Skylighting(([#FunctionTok("scree");#NormalTok("(saq)");],));
#box(image("11-efa_files/figure-typst/unnamed-chunk-11-1.svg"))

=== Parallel analysis
<parallel-analysis>
Parallel analysis (Horn, 1965) is a sophisticated technique that involves simulating random datasets of the same size as our actual dataset, and comparing our dataset's eigenvalues against the random dataset's eigenvalues. Parallel analysis is generally demonstrated using a scree plot with an additional scree line for the simulated datasets. The #NormalTok("fa.parallel()"); function will run this for us.#footnote[The #NormalTok("EFA.dimensions"); package has a similar function called #NormalTok("RAWPAR()");.]

The number of factors to retain is determined by the number of factors where our actual data's eigenvalue exceeds the simulated dataset's eigenvalue.#footnote[As you can see from the output, there are two ways of calculating these eigenvalues - using either a PCA or PAF (principal axis factoring). The #NormalTok("fa.parallel()"); function uses both. Although counterintuitive given that they are not the same technique conceptually, the PCA-based output (i.e.~number of #emph[components]) is the typical method, and actually does perform well at correctly identifying the number of factors to extract. Jamovi appears to default to PAF-based eigenvalues, however.] In this instance, we would choose to retain three factors, as the actual data eigenvalues clearly drop below the simulated data at four factors.

#Skylighting(([#FunctionTok("fa.parallel");#NormalTok("(saq)");],));
#box(image("11-efa_files/figure-typst/unnamed-chunk-12-1.svg"))

#block[
#Skylighting(([#NormalTok("Parallel analysis suggests that the number of factors =  3  and the number of components =  2 ");],));
]
=== Velicer's Minimum Average Partials (MAP) test
<velicers-minimum-average-partials-map-test>
The Minimum Average Partials (MAP; Velicer, 1976) test is another powerful test that is generally useful at identifying how many factors should be extracted. It basically works by calculating the partial correlations between items and finding their average #emph[after] removing the variance explained by the factors.

The #NormalTok("EFA.dimensions"); package contains a series of helpful functions for running some EFA-related checks. The MAP test is included as part of the #NormalTok("MAP()"); function:

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(EFA.dimensions)");],
[#FunctionTok("MAP");#NormalTok("(saq)");],));
#block[
#Skylighting(([],
[],
[#NormalTok("MINIMUM AVERAGE PARTIAL (MAP) TEST");],));
]
#block[
#Skylighting(([],
[#NormalTok("Number of cases = 2571");],));
]
#block[
#Skylighting(([],
[#NormalTok("Number of variables = 9");],));
]
#block[
#Skylighting(([],
[#NormalTok("Specified kind of correlations for this analysis: Pearson");],));
]
#block[
#Skylighting(([],
[],
[#NormalTok("Total Variance Explained (Initial Eigenvalues):");],));
]
#block[
#Skylighting(([#NormalTok("            Eigenvalues    Proportion of Variance    Cumulative Prop. Variance");],
[#NormalTok("Factor 1           2.95                      0.33                         0.33");],
[#NormalTok("Factor 2           1.20                      0.13                         0.46");],
[#NormalTok("Factor 3           0.93                      0.10                         0.57");],
[#NormalTok("Factor 4           0.79                      0.09                         0.65");],
[#NormalTok("Factor 5           0.77                      0.09                         0.74");],
[#NormalTok("Factor 6           0.65                      0.07                         0.81");],
[#NormalTok("Factor 7           0.61                      0.07                         0.88");],
[#NormalTok("Factor 8           0.57                      0.06                         0.94");],
[#NormalTok("Factor 9           0.54                      0.06                         1.00");],));
]
#block[
#Skylighting(([],
[#NormalTok("Velicer's m values");],));
]
#block[
#Skylighting(([#NormalTok("   root   m_pr_squared   m_pr_4rth_power");],
[#NormalTok("      0        0.06439           0.98585");],
[#NormalTok("      1        0.02330           0.12171");],
[#NormalTok("      2        0.04126           0.19847");],
[#NormalTok("      3        0.06469           0.32682");],
[#NormalTok("      4        0.12008           1.09402");],
[#NormalTok("      5        0.20155           3.03325");],
[#NormalTok("      6        0.28088           4.94336");],
[#NormalTok("      7        0.48302          16.87119");],
[#NormalTok("      8        1.00000          91.00000");],));
]
#block[
#Skylighting(([],
[#NormalTok("The smallest partial_r_squared m value is 0.0233");],));
]
#block[
#Skylighting(([],
[#NormalTok("The smallest partial_r_4rth_power m value is 0.12171");],));
]
#block[
#Skylighting(([],
[#NormalTok("The number of components according to the original (1976) MAP Test is = 1");],));
]
#block[
#Skylighting(([],
[#NormalTok("The number of components according to the revised (2000) MAP Test is = 1");],));
]
]
Here, we look for the number of factors with the minimum average partial correlation (hence the name). There are two forms of this test, one based on the original and a revised version - the only difference is that the original looks for the average #emph[squared] correlation, while the revised version calculates it to the 4th power. As we can see, the smallest average correlation in both versions occurs when we extract one factor.

=== How to decide?
<how-to-decide>
Let's summarise our interim decisions so far:

- Kaiser's rule suggests 1 factor
- Visual scree plot inspection suggests either 2 or 4 factors
- Parallel analysis suggests 3 factors
- MAP suggests 1 factor

How do we decide what to use? Decades of empirical and simulation literature have shown a couple of things:

- #strong[Parallel analysis is one of the best methods] of identifying how many factors should be retained. While it is sensitive to various things like sample size, simulation studies have shown that parallel analysis consistently outperforms other methods in terms of how many factors should be retained.
- In contrast, #strong[do not use the Kaiser rule]! The Kaiser rule will consistently misestimate the number of factors - often, the misestimation will be quite severe. It is an extremely popular rule because a) it is simple to interpret and b) SPSS, which was the dominant statistical program of choice for a very long time, defaults to only using the Kaiser rule for PCA/EFA.
- #strong[Theoretical and practical considerations] should also inform your decision making. If parallel analysis suggests 7 factors, for example, but those 7 factors are hard to interpret then you should probably not run with that by default. Instead, the next thing to do would be to step through solutions that remove one factor at a time until an acceptable, interpretable model has been reached.

There are other methods of identifying factors, such as Vellicer's Minimum Average Partials test, but Jamovi does not provide these options. In the absence of any strong justification for anything else, it is best to fall back on parallel analysis. Thus, it's best if we go with three factors.

== Interpreting output
<interpreting-output>
Let's now look at how to actually interpret the output of a factor analysis, including how to make sense of the main numbers that you get out of a basic EFA/PCA output.

=== Extraction methods
<extraction-methods>
PCA only has one method of deriving the eigenvalues of the components, and so it will give the same answer every time you run it on the same dataset. EFA, however, has multiple possible means of estimating factors, which are typically termed extraction methods. We won't go into the details of how exactly they work, but the key thing to know is that the extraction method essentially changes

There are three extraction methods available in Jamovi:

- #strong[Maximum likelihood.] One of the most common options, and provides the most generalisable and robust estimates. ML methods assume normality and generally require large datasets, however.
- #strong[Principal axis factoring.] Principal axis factoring does not make particular assumptions about the normality or distribution of the data, meaning that it is good at handling more complex datasets.
- #strong[Minimum residuals.] The minimum residual method is sort of a middle-ground option between the two, but isn't as commonly used in psychological research.

Under ideal conditions, maximum likelihood (ML) and PA (principal axis) methods will generally give very similar estimates of the factors. When data are severely non-normal (or you want to anticipate that it will be), it is better to go with PA in the first instance. Otherwise, ML estimates are generally the way to go.

To run a factor analysis in r, we use the #NormalTok("fa"); function from #NormalTok("psych");. At minimum, we must specify the following:

- The dataset as the first argument
- The number of factors we want to extract
- The type of rotation - for now set this to "none", as we'll talk about this later
- The factoring method, #NormalTok("fm"); - as above. #NormalTok("\"ml\""); stands for maximum likelihood, #NormalTok("\"pa\""); stands for principal axis factoring and #NormalTok("\"minres\""); stands for minimum residuals.

#block[
#Skylighting(([#NormalTok("saq_efa ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("fa");#NormalTok("(");],
[#NormalTok("  saq,");],
[#NormalTok("  ");#AttributeTok("nfactors =");#NormalTok(" ");#DecValTok("3");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("rotate =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("fm =");#NormalTok(" ");#StringTok("\"ml\"");],
[#NormalTok(")");],));
]
=== Interpreting output
<interpreting-output-1>
Below is the main output of our EFA. This is what we call a factor matrix:

#block[
#Skylighting(([#NormalTok("saq_efa");],));
#block[
#Skylighting(([#NormalTok("Factor Analysis using method =  ml");],
[#NormalTok("Call: fa(r = saq, nfactors = 3, rotate = \"none\", fm = \"ml\")");],
[#NormalTok("Standardized loadings (pattern matrix) based upon correlation matrix");],
[#NormalTok("      ML1   ML2   ML3   h2   u2 com");],
[#NormalTok("q01  0.59  0.31 -0.12 0.46 0.54 1.6");],
[#NormalTok("q02 -0.25  0.25  0.32 0.23 0.77 2.8");],
[#NormalTok("q04  0.62  0.23 -0.02 0.44 0.56 1.3");],
[#NormalTok("q05  0.56  0.19 -0.06 0.36 0.64 1.3");],
[#NormalTok("q06  0.55 -0.21  0.32 0.45 0.55 2.0");],
[#NormalTok("q14  0.63 -0.12  0.10 0.42 0.58 1.1");],
[#NormalTok("q15  0.55 -0.15  0.10 0.34 0.66 1.2");],
[#NormalTok("q19 -0.37  0.21  0.22 0.23 0.77 2.3");],
[#NormalTok("q22 -0.28  0.31  0.24 0.24 0.76 2.9");],
[],
[#NormalTok("                       ML1  ML2  ML3");],
[#NormalTok("SS loadings           2.33 0.47 0.35");],
[#NormalTok("Proportion Var        0.26 0.05 0.04");],
[#NormalTok("Cumulative Var        0.26 0.31 0.35");],
[#NormalTok("Proportion Explained  0.74 0.15 0.11");],
[#NormalTok("Cumulative Proportion 0.74 0.89 1.00");],
[],
[#NormalTok("Mean item complexity =  1.8");],
[#NormalTok("Test of the hypothesis that 3 factors are sufficient.");],
[],
[#NormalTok("df null model =  36  with the objective function =  1.43 with Chi Square =  3674.74");],
[#NormalTok("df of  the model are 12  and the objective function was  0.01 ");],
[],
[#NormalTok("The root mean square of the residuals (RMSR) is  0.01 ");],
[#NormalTok("The df corrected root mean square of the residuals is  0.02 ");],
[],
[#NormalTok("The harmonic n.obs is  2571 with the empirical chi square  14.26  with prob <  0.28 ");],
[#NormalTok("The total n.obs was  2571  with Likelihood Chi Square =  33.87  with prob <  0.00071 ");],
[],
[#NormalTok("Tucker Lewis Index of factoring reliability =  0.982");],
[#NormalTok("RMSEA index =  0.027  and the 90 % confidence intervals are  0.016 0.037");],
[#NormalTok("BIC =  -60.35");],
[#NormalTok("Fit based upon off diagonal values = 1");],
[#NormalTok("Measures of factor score adequacy             ");],
[#NormalTok("                                                   ML1   ML2   ML3");],
[#NormalTok("Correlation of (regression) scores with factors   0.89  0.65  0.59");],
[#NormalTok("Multiple R square of scores with factors          0.79  0.43  0.35");],
[#NormalTok("Minimum correlation of possible factor scores     0.59 -0.15 -0.31");],));
]
]
What do these numbers mean? Firstly, each value in each factor column (labelled #NormalTok("ML1");, #NormalTok("ML2"); etc) gives us our loadings. Note that as per the common factor model we described before, we estimate a loading for every variable on every factor. However, this can be a bit gross to interpret, so we generally choose to suppress (not remove) loadings below a certain threshold. By default, Jamovi will hide loadings below 0.3. We can also sort the items based on their loadings. To do this, we use the #NormalTok("fa.sort()"); function and feed in our EFA object. We can then use #NormalTok("print()"); to clean up this output with two arguments: #NormalTok("digits"); to show rounding, and #NormalTok("cut"); to suppress values below a certain size. This gives us a nicer output:

#block[
#Skylighting(([#NormalTok("saq_efa ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("fa.sort");#NormalTok("(saq_efa) ");],
[#FunctionTok("print");#NormalTok("(saq_efa, ");#AttributeTok("digits =");#NormalTok(" ");#DecValTok("3");#NormalTok(", ");#AttributeTok("cut =");#NormalTok(" .");#DecValTok("30");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Factor Analysis using method =  ml");],
[#NormalTok("Call: fa(r = saq, nfactors = 3, rotate = \"none\", fm = \"ml\")");],
[#NormalTok("Standardized loadings (pattern matrix) based upon correlation matrix");],
[#NormalTok("       ML1    ML2    ML3    h2    u2  com");],
[#NormalTok("q14  0.631               0.420 0.580 1.12");],
[#NormalTok("q04  0.622               0.441 0.559 1.27");],
[#NormalTok("q01  0.589  0.311        0.458 0.542 1.61");],
[#NormalTok("q05  0.562               0.358 0.642 1.26");],
[#NormalTok("q15  0.551               0.337 0.663 1.23");],
[#NormalTok("q06  0.546         0.324 0.448 0.552 1.97");],
[#NormalTok("q19 -0.371               0.229 0.771 2.27");],
[#NormalTok("q22         0.314        0.238 0.762 2.88");],
[#NormalTok("q02                0.319 0.229 0.771 2.84");],
[],
[#NormalTok("                        ML1   ML2   ML3");],
[#NormalTok("SS loadings           2.333 0.474 0.352");],
[#NormalTok("Proportion Var        0.259 0.053 0.039");],
[#NormalTok("Cumulative Var        0.259 0.312 0.351");],
[#NormalTok("Proportion Explained  0.738 0.150 0.111");],
[#NormalTok("Cumulative Proportion 0.738 0.889 1.000");],
[],
[#NormalTok("Mean item complexity =  1.8");],
[#NormalTok("Test of the hypothesis that 3 factors are sufficient.");],
[],
[#NormalTok("df null model =  36  with the objective function =  1.432 with Chi Square =  3674.737");],
[#NormalTok("df of  the model are 12  and the objective function was  0.013 ");],
[],
[#NormalTok("The root mean square of the residuals (RMSR) is  0.012 ");],
[#NormalTok("The df corrected root mean square of the residuals is  0.021 ");],
[],
[#NormalTok("The harmonic n.obs is  2571 with the empirical chi square  14.257  with prob <  0.285 ");],
[#NormalTok("The total n.obs was  2571  with Likelihood Chi Square =  33.874  with prob <  0.000706 ");],
[],
[#NormalTok("Tucker Lewis Index of factoring reliability =  0.982");],
[#NormalTok("RMSEA index =  0.0266  and the 90 % confidence intervals are  0.0163 0.0374");],
[#NormalTok("BIC =  -60.351");],
[#NormalTok("Fit based upon off diagonal values = 0.998");],
[#NormalTok("Measures of factor score adequacy             ");],
[#NormalTok("                                                    ML1    ML2    ML3");],
[#NormalTok("Correlation of (regression) scores with factors   0.892  0.652  0.587");],
[#NormalTok("Multiple R square of scores with factors          0.795  0.425  0.345");],
[#NormalTok("Minimum correlation of possible factor scores     0.590 -0.150 -0.310");],));
]
]
Statistically speaking, in a factor matrix each loading is a #strong[regression coefficient] for the latent factor predicting the variable. We can interpret them as we would with normal regressions, except this is a regression coefficient for our latent variable predicting each observed variable. For example, the loading for q14 on factor 1 is 0.631. This means that for every 1 unit increase on latent factor 1, scores on Q14 increase by .631 units.

Jamovi typically only gives you the #strong[uniqueness] column, #NormalTok("u2");, which gives us the value of unique variance as a percentage. This is how much variance in each item is not explained by the factors we have chosen. In this instance, 58% of the variance in Q14 is not explained by the three factors.

Generally though, it's easier to think in terms of #strong[communalities], or the values in the #NormalTok("h2"); column, which is the amount of variance that is explained by the factors. Communalities are simply 1 - uniqueness; thus, the communality of Q14 is 0.420, which indicates that 42% of the variance in Q14 is explained by the three factors. Higher communalities indicate that the factors collectively explain more variance in the observed variable.

How is this value calculated? Communalities are the sum of the squared factor loadings. Therefore, we can look at Q14's factor loadings in the first (pre-sorted) output table, and calculate the communality as:

$ h^2 = .631^2 + - .116^2 + .0963^2 $

Which gives us an answer of approximately 0.420:

#block[
#Skylighting(([#NormalTok(".");#DecValTok("631");#SpecialCharTok("^");#DecValTok("2");#NormalTok(" ");#SpecialCharTok("+");#NormalTok(" (");#SpecialCharTok("-");#NormalTok(".");#DecValTok("116");#NormalTok(")");#SpecialCharTok("^");#DecValTok("2");#NormalTok(" ");#SpecialCharTok("+");#NormalTok(" .");#DecValTok("0963");#SpecialCharTok("^");#DecValTok("2");],));
#block[
#Skylighting(([#NormalTok("[1] 0.4208907");],));
]
]
=== Total variance explained
<total-variance-explained>
The output of #NormalTok("psych"); will also give you a brief table of the total amount of variance explained by each factor. This is shown in the output of #NormalTok("fa");, but can also be accessed again below. It is generally useful to at least report the total cumulative variance explained by all factors. In this case, the three factors collectively explain 35.1% of the total variance in the data (shown by the row saying "Cumulative var").

#block[
#Skylighting(([#NormalTok("saq_efa");#SpecialCharTok("$");#NormalTok("Vaccounted");],));
#block[
#Skylighting(([#NormalTok("                            ML1        ML2        ML3");],
[#NormalTok("SS loadings           2.3325379 0.47409809 0.35202983");],
[#NormalTok("Proportion Var        0.2591709 0.05267757 0.03911443");],
[#NormalTok("Cumulative Var        0.2591709 0.31184845 0.35096287");],
[#NormalTok("Proportion Explained  0.7384567 0.15009441 0.11144890");],
[#NormalTok("Cumulative Proportion 0.7384567 0.88855110 1.00000000");],));
]
]
== Rotation, and interpreting output again
<rotation-and-interpreting-output-again>
You may have noticed that on the previous page, we didn't make much of an effort to actually talk about what the factors were or what they meant. That's because the output that we got on the previous page isn't actually terribly informative or easy to interpret. To help with this, in EFA we perform a technique called #strong[rotation].

=== Rotations
<rotations>
Rotations are a technique in EFA that are done to help with the interpretability of the factor solution. The key aim of rotation is to achieve #strong[simple structure] where possible.

You may have noticed that the matrix from the previous page has quite a few variables with high enough loadings on multiple factors. This is called #strong[cross-loading], and indicates that two factors explain the variable. This is not easily interpretable! Ideally, in a robust simple structure we want:

- Only one loading per variable
- At least three loadings per factor

#block[
#Skylighting(([#FunctionTok("print");#NormalTok("(saq_efa, ");#AttributeTok("digits =");#NormalTok(" ");#DecValTok("3");#NormalTok(", ");#AttributeTok("cut =");#NormalTok(" ");#FloatTok("0.3");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Factor Analysis using method =  ml");],
[#NormalTok("Call: fa(r = saq, nfactors = 3, rotate = \"none\", fm = \"ml\")");],
[#NormalTok("Standardized loadings (pattern matrix) based upon correlation matrix");],
[#NormalTok("       ML1    ML2    ML3    h2    u2  com");],
[#NormalTok("q14  0.631               0.420 0.580 1.12");],
[#NormalTok("q04  0.622               0.441 0.559 1.27");],
[#NormalTok("q01  0.589  0.311        0.458 0.542 1.61");],
[#NormalTok("q05  0.562               0.358 0.642 1.26");],
[#NormalTok("q15  0.551               0.337 0.663 1.23");],
[#NormalTok("q06  0.546         0.324 0.448 0.552 1.97");],
[#NormalTok("q19 -0.371               0.229 0.771 2.27");],
[#NormalTok("q22         0.314        0.238 0.762 2.88");],
[#NormalTok("q02                0.319 0.229 0.771 2.84");],
[],
[#NormalTok("                        ML1   ML2   ML3");],
[#NormalTok("SS loadings           2.333 0.474 0.352");],
[#NormalTok("Proportion Var        0.259 0.053 0.039");],
[#NormalTok("Cumulative Var        0.259 0.312 0.351");],
[#NormalTok("Proportion Explained  0.738 0.150 0.111");],
[#NormalTok("Cumulative Proportion 0.738 0.889 1.000");],
[],
[#NormalTok("Mean item complexity =  1.8");],
[#NormalTok("Test of the hypothesis that 3 factors are sufficient.");],
[],
[#NormalTok("df null model =  36  with the objective function =  1.432 with Chi Square =  3674.737");],
[#NormalTok("df of  the model are 12  and the objective function was  0.013 ");],
[],
[#NormalTok("The root mean square of the residuals (RMSR) is  0.012 ");],
[#NormalTok("The df corrected root mean square of the residuals is  0.021 ");],
[],
[#NormalTok("The harmonic n.obs is  2571 with the empirical chi square  14.257  with prob <  0.285 ");],
[#NormalTok("The total n.obs was  2571  with Likelihood Chi Square =  33.874  with prob <  0.000706 ");],
[],
[#NormalTok("Tucker Lewis Index of factoring reliability =  0.982");],
[#NormalTok("RMSEA index =  0.0266  and the 90 % confidence intervals are  0.0163 0.0374");],
[#NormalTok("BIC =  -60.351");],
[#NormalTok("Fit based upon off diagonal values = 0.998");],
[#NormalTok("Measures of factor score adequacy             ");],
[#NormalTok("                                                    ML1    ML2    ML3");],
[#NormalTok("Correlation of (regression) scores with factors   0.892  0.652  0.587");],
[#NormalTok("Multiple R square of scores with factors          0.795  0.425  0.345");],
[#NormalTok("Minimum correlation of possible factor scores     0.590 -0.150 -0.310");],));
]
]
Rotation can help us achieve this. What rotations essentially do is change how variance is distributed within each factor. That wording is extremely important to note. It does not change our data in any way - the actual amount of variance explained by each factor does not change. What does change is how variance is distributed across the factors, which has the effect of then changing the loadings. But the actual data does not change!!

There are two families of rotations that we can employ.

- #strong[Orthogonal] rotations force factors to be #strong[uncorrelated].
- #strong[Oblique] rotations allow factors to be correlated.

The below diagram visualises what rotations do:

#box(image("img/rotations.png"))

#strong[Which rotation to choose?] In psychology, everything tends to be correlated with everything else, and it's extremely rare that we would get an instance where two factors do not correlate at all. For that reason, #strong[oblique rotations are generally the way to go]. Orthogonal rotations are extremely hard to justify without strong a-priori evidence - and even if two factors are uncorrelated, oblique rotations will give the same solution as orthogonal ones. In short, there's generally no reason to prefer an orthogonal rotation by default.

=== Rotated factor solution
<rotated-factor-solution>
Let's apply an oblique rotation to our factor analysis. The default oblique rotation is called oblimin. To do this, we need to re-run our #NormalTok("fa()"); function with a rotation specified.

#block[
#Skylighting(([#NormalTok("saq_efa_rot ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("fa");#NormalTok("(");],
[#NormalTok("  saq,");],
[#NormalTok("  ");#AttributeTok("nfactors =");#NormalTok(" ");#DecValTok("3");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("rotate =");#NormalTok(" ");#StringTok("\"oblimin\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("fm =");#NormalTok(" ");#StringTok("\"ml\"");],
[#NormalTok(")");],));
]
This produces the following output, which we now term a pattern matrix:

#block[
#Skylighting(([#NormalTok("saq_efa_rot ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("fa.sort");#NormalTok("() ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("print");#NormalTok("(");#AttributeTok("digits =");#NormalTok(" ");#DecValTok("3");#NormalTok(", ");#AttributeTok("cut =");#NormalTok(" ");#FloatTok("0.3");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Factor Analysis using method =  ml");],
[#NormalTok("Call: fa(r = saq, nfactors = 3, rotate = \"oblimin\", fm = \"ml\")");],
[#NormalTok("Standardized loadings (pattern matrix) based upon correlation matrix");],
[#NormalTok("       ML1    ML3    ML2    h2    u2  com");],
[#NormalTok("q01  0.714               0.458 0.542 1.02");],
[#NormalTok("q04  0.609               0.441 0.559 1.06");],
[#NormalTok("q05  0.553               0.358 0.642 1.02");],
[#NormalTok("q06         0.704        0.448 0.552 1.01");],
[#NormalTok("q14         0.440        0.420 0.580 1.57");],
[#NormalTok("q15         0.434        0.337 0.663 1.32");],
[#NormalTok("q02                0.506 0.229 0.771 1.04");],
[#NormalTok("q22                0.488 0.238 0.762 1.08");],
[#NormalTok("q19                0.412 0.229 0.771 1.11");],
[],
[#NormalTok("                        ML1   ML3   ML2");],
[#NormalTok("SS loadings           1.360 1.043 0.756");],
[#NormalTok("Proportion Var        0.151 0.116 0.084");],
[#NormalTok("Cumulative Var        0.151 0.267 0.351");],
[#NormalTok("Proportion Explained  0.431 0.330 0.239");],
[#NormalTok("Cumulative Proportion 0.431 0.761 1.000");],
[],
[#NormalTok(" With factor correlations of ");],
[#NormalTok("       ML1    ML3    ML2");],
[#NormalTok("ML1  1.000  0.591 -0.411");],
[#NormalTok("ML3  0.591  1.000 -0.448");],
[#NormalTok("ML2 -0.411 -0.448  1.000");],
[],
[#NormalTok("Mean item complexity =  1.1");],
[#NormalTok("Test of the hypothesis that 3 factors are sufficient.");],
[],
[#NormalTok("df null model =  36  with the objective function =  1.432 with Chi Square =  3674.737");],
[#NormalTok("df of  the model are 12  and the objective function was  0.013 ");],
[],
[#NormalTok("The root mean square of the residuals (RMSR) is  0.012 ");],
[#NormalTok("The df corrected root mean square of the residuals is  0.021 ");],
[],
[#NormalTok("The harmonic n.obs is  2571 with the empirical chi square  14.257  with prob <  0.285 ");],
[#NormalTok("The total n.obs was  2571  with Likelihood Chi Square =  33.874  with prob <  0.000706 ");],
[],
[#NormalTok("Tucker Lewis Index of factoring reliability =  0.982");],
[#NormalTok("RMSEA index =  0.0266  and the 90 % confidence intervals are  0.0163 0.0374");],
[#NormalTok("BIC =  -60.351");],
[#NormalTok("Fit based upon off diagonal values = 0.998");],
[#NormalTok("Measures of factor score adequacy             ");],
[#NormalTok("                                                    ML1    ML3    ML2");],
[#NormalTok("Correlation of (regression) scores with factors   0.718  0.672  0.636");],
[#NormalTok("Multiple R square of scores with factors          0.515  0.452  0.405");],
[#NormalTok("Minimum correlation of possible factor scores     0.031 -0.096 -0.190");],));
]
]
Now we can see our simple structure taking effect, and this output is much more interpretable from before. These values are still regression coefficients between each latent factor and each variable, but now we can group these variables into their underlying latent factors much more easily. We can see that questions 1, 4 and 5 are best captured by factor 1, questions 6, 14 and 15 by factor 2 and questions 2, 19 and 22 by factor 3.

#strong[One warning here]. On the previous page, where we had an unrotated solution, the communalities were calculated by summing the squared factor loadings for each variable. That rule no longer applies here because by allowing the factors to correlate, the regression loadings now capture non-specific variance. Summing the squared factor loadings will lead to greater communality values than what they actually are. However, as you can hopefully see in the uniqueness column, the actual communalities have not changed. Rotation does not change how much variance is explained in total - only how that variance is distributed!

Oblique rotations will also generate a #strong[factor correlation matrix]. This calculates the correlations between the factors - remembering that by specifying an oblique rotation, we allowed them to correlate:

#block[
#Skylighting(([#NormalTok("saq_efa_rot");#SpecialCharTok("$");#NormalTok("Phi");],));
#block[
#Skylighting(([#NormalTok("           ML1        ML3        ML2");],
[#NormalTok("ML1  1.0000000  0.5909483 -0.4107233");],
[#NormalTok("ML3  0.5909483  1.0000000 -0.4475027");],
[#NormalTok("ML2 -0.4107233 -0.4475027  1.0000000");],));
]
]
Finally, we get the table of variance explained. This is now not as useful because of the same reason we cannot sum the squared factor loadings - each factor on its own now captures shared variance across the other factors as they are allowed to correlate. However, the total amount of variance explained is still 35.1%; once again, this does not change.

#block[
#Skylighting(([#NormalTok("saq_efa_rot");#SpecialCharTok("$");#NormalTok("Vaccounted");],));
#block[
#Skylighting(([#NormalTok("                            ML1       ML3        ML2");],
[#NormalTok("SS loadings           1.3601670 1.0425634 0.75593543");],
[#NormalTok("Proportion Var        0.1511297 0.1158404 0.08399283");],
[#NormalTok("Cumulative Var        0.1511297 0.2669700 0.35096287");],
[#NormalTok("Proportion Explained  0.4306144 0.3300645 0.23932111");],
[#NormalTok("Cumulative Proportion 0.4306144 0.7606789 1.00000000");],));
]
]
= Mediation and Moderation
<mediation-and-moderation>
Sometimes, the hypotheses we want to test are ones where the effect of interest works in a very specific way. In some cases, we might hypothesise that the relationship between two variables is actually best explained by a third variable that acts between them. For instance, we might predict that a relationship between sugar levels in food and happiness is best explained by food intake - we might eat more sugar, and eating more makes us happier (or something like that).#footnote[I'm no dietitian or food psychology expert so I make no claims as to the veracity or accuracy of this statement.] This kind of hypothesis is called a #strong[mediation], and is common in psychological research as a lot of our work deals with #emph[processes.]

In other instances, we might expect interaction effects like what we saw in two-way ANOVAs, but between continuous predictors. Note that up until this point we have only considered categorical x categorical interactions within an ANOVA context, so now is a good time to explore continuous x continuous interactions. We describe these effects as #strong[moderation] effects.

This chapter will cover both mediation and moderation.

== Mediation: Intro
<mediation-intro>
#block(fill: rgb("#f5f5f5"))[
We start with an overview of the concept of mediation, with special consideration to its interpretation for the time being.

]
=== Introduction to mediation
<introduction-to-mediation>
#strong[Mediation] refers to a specific model where we hypothesise that the relationship between a predictor X and an outcome Y is explained by the effect of a third #emph[mediating] variable. You can imagine a simple linear regression in the following way, with c representing the #strong[direct effect] (or the regression coefficient) between the predictor and the outcome.

#align(center)[#box(image("img/mediation_1.svg"))]
But what happens if we believe that there actually isn't as direct of a relationship? In other words, we believe that our predictor X actually predicts/affects Y through a mediating variable, M? That might look like the following:

#align(center)[#box(image("img/mediation_2.svg"))]
In other words, mediation occurs when the effect of X on Y is explained through the effect of M. When paired with clever and careful study designs, mediations can be used to #strong[test causality]. The underlying principle of the diagram above is that X causes M, and M causes Y; i.e.~we implicitly specify #strong[directional relationships] between our predictor, mediator and outcome.

=== In mathematical terms
<in-mathematical-terms>
The basic idea of mediation is that the #strong[total direct effect, c, should reduce] once the mediator is accounted for. This new direct effect is denoted as c' (c-prime). If a mediating effect is significant, then #emph[c'] should be smaller than #emph[c]\; after all, if the mediator explains what is going on then this should explain the direct effect between the predictor and outcome.

The a and b paths denote the relationship between the predictor and mediator (a), and the mediator and the outcome (b). Together, they denote the #strong[indirect effect] of the mediator, which we denote as ab - literally, the product of the two coefficients.

What is the relationship between the direct and indirect effect? Well, if the original effect c is the #strong[total] effect, we can decompose this as:

Total effect = direct effect (c') + indirect effect (ab)

Without a mediator, the indirect effect ab is equal to zero, and so we only have a direct effect. However, if the indirect effect fully explains the relationship between the predictor and the outcome then we would expect the direct effect (c') to be close to 0, and the indirect effect to fully explain/comprise the total effect.

== Mediation: Causal steps
<mediation-causal-steps>
#block(fill: rgb("#f5f5f5"))[
No introduction to mediation is complete without considering the causal steps approach, which held dominance as the main method of testing mediations for a while. Below is an overview of this approach.

]
=== The causal steps approach
<the-causal-steps-approach>
The causal steps approach outlined by Baron and Kenny (1986) was one of the first defined ways to test for a mediation. The name refers to a sequence of analytical steps that must be taken in order to apparently demonstrate a mediation, in line with the figure we saw on the previous page:

#align(center)[#box(image("img/mediation_2.svg"))]
To illustrate the causal steps approach (and subsequent approaches), we will use a fictional dataset below. This dataset contains scores on students' grades, self-esteem and happiness. We theorise that the relationship between a student's grades and their happiness is mediated by their self-esteem, which gives rise to the hypothetical mediation below:

#align(center)[#box(image("img/mediation_3.png"))]
#block[
#Skylighting(([#NormalTok("med_data ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"medmod\"");#NormalTok(", ");#StringTok("\"med_grades.csv\"");#NormalTok("))");],));
]
=== Step 1: Test the direct effect (c)
<step-1-test-the-direct-effect-c>
The first step in the classic causal steps approach is simply to see whether our predictor X predicts the outcome Y, using a linear regression. This tests the direct effect, c.~The magnitude of this direct effect is 0.396.

#block[
#Skylighting(([#NormalTok("step_1 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(happiness ");#SpecialCharTok("~");#NormalTok(" grade, ");#AttributeTok("data =");#NormalTok(" med_data)");],
[#FunctionTok("summary");#NormalTok("(step_1)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = happiness ~ grade, data = med_data)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("    Min      1Q  Median      3Q     Max ");],
[#NormalTok("-5.0262 -1.2340 -0.3282  1.5583  5.1622 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("            Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)   2.8572     0.6932   4.122 7.88e-05 ***");],
[#NormalTok("grade         0.3961     0.1112   3.564 0.000567 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 1.929 on 98 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.1147,    Adjusted R-squared:  0.1057 ");],
[#NormalTok("F-statistic:  12.7 on 1 and 98 DF,  p-value: 0.0005671");],));
]
]
=== Step 2: Test the predictor and mediator (a)
<step-2-test-the-predictor-and-mediator-a>
The next step is to see whether the predictor significantly predicts the mediator, which denotes the a path. The estimate for a in this case is 0.561.

#block[
#Skylighting(([#NormalTok("step_2 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(self_esteem ");#SpecialCharTok("~");#NormalTok(" grade, ");#AttributeTok("data =");#NormalTok(" med_data)");],
[#FunctionTok("summary");#NormalTok("(step_2)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = self_esteem ~ grade, data = med_data)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("    Min      1Q  Median      3Q     Max ");],
[#NormalTok("-4.3046 -0.8656  0.1344  1.1344  4.6954 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("            Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)  1.49952    0.58920   2.545   0.0125 *  ");],
[#NormalTok("grade        0.56102    0.09448   5.938 4.39e-08 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 1.639 on 98 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.2646,    Adjusted R-squared:  0.2571 ");],
[#NormalTok("F-statistic: 35.26 on 1 and 98 DF,  p-value: 4.391e-08");],));
]
]
=== Step 3: Test the predictor and mediator on the outcome (b)
<step-3-test-the-predictor-and-mediator-on-the-outcome-b>
This step involves running a multiple regression with both X and M as predictors, and Y as the outcome. This is because as in the model above, the effect of Y is determined by both the effect of the predictor and the mediator. The estimate for b is the regression coefficient for the mediator in this analysis - in this case, b = 0.6355.

#block[
#Skylighting(([#NormalTok("step_3 ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(happiness ");#SpecialCharTok("~");#NormalTok(" grade ");#SpecialCharTok("+");#NormalTok(" self_esteem, ");#AttributeTok("data =");#NormalTok(" med_data)");],
[#FunctionTok("summary");#NormalTok("(step_3)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = happiness ~ grade + self_esteem, data = med_data)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("    Min      1Q  Median      3Q     Max ");],
[#NormalTok("-3.7631 -1.2393  0.0308  1.0832  4.0055 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("            Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)   1.9043     0.6055   3.145   0.0022 ** ");],
[#NormalTok("grade         0.0396     0.1096   0.361   0.7187    ");],
[#NormalTok("self_esteem   0.6355     0.1005   6.321 7.92e-09 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 1.631 on 97 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.373, Adjusted R-squared:  0.3601 ");],
[#NormalTok("F-statistic: 28.85 on 2 and 97 DF,  p-value: 1.471e-10");],));
]
]
=== Step 4: Decide the extent of mediation
<step-4-decide-the-extent-of-mediation>
Recall on the previous page that the idea of mediation is to see how close #emph[c], the direct effect, gets to zero after mediation (i.e.~#emph[c'] = 0). The significance of the mediated direct effect, #emph[c'], as well as its magnitude are generally used to determine the extent to which this direct effect has been mediated.

If #strong[full mediation] has occurred, the effect of #emph[c'] should be non-significant and close to 0. If #emph[c'] is still significant and not close to 0, but all the other steps are significant, then #strong[partial mediation] is said to have occurred.

In our instance, the estimate of #emph[c'] is 0.0396, with a #emph[p]-value of .719. Given that the #emph[c'] effect is non-significant, we would say that self-esteem #strong[fully mediates] the relationship between grades and happiness.

One final check - also recall that the total effect, #emph[c], can be broken down into the direct effect #emph[c'] and the indirect effect #emph[ab]. You can manually check the maths here - #emph[ab] (0.561 \* 0.6355) + 0.0396 (the coefficient for #emph[c']) gives us 0.396, which was our initial estimate of the total effect #emph[c].

=== Problems with the causal steps approach
<problems-with-the-causal-steps-approach>
The causal steps approach is not often used in mediation analyses anymore for a couple of reasons:

- #strong[Step 1 is not always necessary]. A non-significant #emph[c] does not necessarily indicate that there is no mediation - in fact, sometimes we can observe #strong[suppression effects], where the indirect effect is positive while the direct effect is negative (or vice versa). This can happen when the causal chains act in opposite directions, thereby cancelling out the overall effect.
- This approach does not #emph[really] test the indirect path - only its individual components. Because we are interested in the effect of the mediating path, i.e.~#emph[ab], it makes sense that we would want to know if that overall indirect effect is significant. However, this approach doesn't actually test for that.
- Related to the above, Type II errors can be higher with this approach - some mediation effects can be missed.

== Mediation: Sobel's test and bootstrapping
<mediation-sobels-test-and-bootstrapping>
#block(fill: rgb("#f5f5f5"))[
So the causal steps approach doesn't really work for mediation… What now? Well, there are two more contemporary methods of testing mediations. While the latter (the bootstrap method) is the most recommended, we demonstrate both for completion's sake.

]
=== Running mediations in R
<running-mediations-in-r>
There are many packages available to run mediations in R, including the well-known package #NormalTok("mediation"); package. One of the most popular software tools for running mediations (and moderations), particularly for SPSS users, is the #link("https://processmacro.org/index.html")[PROCESS macro by Andrew Hayes]. PROCESS is essentially a set of code that can run a series of what we call #emph[conditional process models] - including mediation and moderation.

Note that due to copyright reasons, the R version of process isn't available on this book's corresponding GitHub repo; however, it can be downloaded for free from the official site using the link above. Detailed documentation is available in Hayes (2022). Loading PROCESS is not quite like loading a package in R as it isn't available in package form. To load it, you must use the #NormalTok("source()"); function in base R, which will run another R script. Place the #NormalTok("process.R"); file somewhere you can find it, and pass the file path to #NormalTok("source()");. It will take a little bit to load depending on your computer's specs, but if it has loaded correctly then you should see the following:

#block[
#Skylighting(([#FunctionTok("source");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"code\"");#NormalTok(", ");#StringTok("\"process.R\"");#NormalTok("))");],));
#block[
#Skylighting(([],
[#NormalTok("**************** PROCESS Procedure for R Version 5.0 ****************** ");],
[#NormalTok(" ");],
[#NormalTok("           Written by Andrew F. Hayes, Ph.D.  www.afhayes.com              ");],
[#NormalTok("   Documentation available in Hayes (2022). www.guilford.com/p/hayes3   ");],
[#NormalTok(" ");],
[#NormalTok("*********************************************************************** ");],
[#NormalTok(" ");],
[#NormalTok("PROCESS is now ready for use.");],
[#NormalTok("Copyright 2013-2025 by Andrew F. Hayes ALL RIGHTS RESERVED");],
[#NormalTok("Workshop schedule at haskayne.ucalgary.ca/CCRAM ");],
[#NormalTok("Information about PROCESS available at processmacro.org/faq.html ");],));
]
]
Key to the PROCESS macro is the #NormalTok("process()"); function, which is basically a does-it-all function that will run both mediations and moderations.

=== Sobel's test
<sobels-test>
The first, and perhaps most common method, goes by a couple of names: Sobel's test or the delta method are perhaps the two most well known. Jamovi calls this the #strong[Standard] method. Sobel's test is a direct test of the significance of the #emph[ab] pathway in a mediation.

The principle behind Sobel's test is actually relatively simple: it is analogous to a #emph[t]-test, in that a #emph[t]-statistic is calculated by dividing the estimate of #emph[ab] by its estimated standard error:

$ t_(a b) = frac(a b, S E_(a b)) $

From there, a #emph[p]-value can be calculated by using this #emph[t]-statistic and comparing it against a null #emph[t]-distribution, much like you would with a #emph[t]-test or a regression slope.

Note that Sobel's test #strong[assumes normality].

To run a mediation, we use the #NormalTok("process()"); function as follows: - #NormalTok("data"); specifies the dataset. - #NormalTok("x");, #NormalTok("y"); and #NormalTok("m"); specify the predictor, outcome and mediator respectively. - #NormalTok("model = 4"); specifies that we want to run a mediation. (PROCESS comes with 20-odd different model types!) - #NormalTok("normal = 1"); and #NormalTok("boot = 0"); specifies that we only want a Sobel test for the indirect effect.

#block[
#Skylighting(([#NormalTok("med_sobel ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("process");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("data =");#NormalTok(" med_data,");],
[#NormalTok("  ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"happiness\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"grade\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("m =");#NormalTok(" ");#StringTok("\"self_esteem\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("model =");#NormalTok(" ");#DecValTok("4");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("normal =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("boot =");#NormalTok(" ");#DecValTok("0");],
[#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("**************** PROCESS Procedure for R Version 5.0 ****************** ");],
[#NormalTok(" ");],
[#NormalTok("           Written by Andrew F. Hayes, Ph.D.  www.afhayes.com              ");],
[#NormalTok("   Documentation available in Hayes (2022). www.guilford.com/p/hayes3   ");],
[#NormalTok(" ");],
[#NormalTok("*********************************************************************** ");],
[#NormalTok("                    ");],
[#NormalTok("  Model: 4          ");],
[#NormalTok("      Y: happiness  ");],
[#NormalTok("      X: grade      ");],
[#NormalTok("      M: self_esteem");],
[],
[#NormalTok("Sample size: 100");],
[],
[],
[#NormalTok("*********************************************************************** ");],
[#NormalTok("Outcome Variable: self_esteem");],
[],
[#NormalTok("Model Summary: ");],
[#NormalTok("          R      R-sq       MSE         F       df1       df2         p");],
[#NormalTok("     0.5144    0.2646    2.6868   35.2586    1.0000   98.0000    0.0000");],
[],
[#NormalTok("Model: ");],
[#NormalTok("             coeff        se         t         p      LLCI      ULCI");],
[#NormalTok("constant    1.4995    0.5892    2.5450    0.0125    0.3303    2.6688");],
[#NormalTok("grade       0.5610    0.0945    5.9379    0.0000    0.3735    0.7485");],
[],
[#NormalTok("*********************************************************************** ");],
[#NormalTok("Outcome Variable: happiness");],
[],
[#NormalTok("Model Summary: ");],
[#NormalTok("          R      R-sq       MSE         F       df1       df2         p");],
[#NormalTok("     0.6107    0.3730    2.6613   28.8524    2.0000   97.0000    0.0000");],
[],
[#NormalTok("Model: ");],
[#NormalTok("                coeff        se         t         p      LLCI      ULCI");],
[#NormalTok("constant       1.9043    0.6055    3.1452    0.0022    0.7026    3.1059");],
[#NormalTok("grade          0.0396    0.1096    0.3612    0.7187   -0.1780    0.2572");],
[#NormalTok("self_esteem    0.6355    0.1005    6.3212    0.0000    0.4360    0.8350");],
[],
[#NormalTok("**************** DIRECT AND INDIRECT EFFECTS OF X ON Y ****************");],
[],
[#NormalTok("Direct effect of X on Y:");],
[#NormalTok("     effect        se         t         p      LLCI      ULCI");],
[#NormalTok("     0.0396    0.1096    0.3612    0.7187   -0.1780    0.2572");],
[],
[#NormalTok("Indirect effect(s) of X on Y:");],
[#NormalTok("               Effect");],
[#NormalTok("self_esteem    0.3565");],
[],
[#NormalTok("Normal theory test for indirect effect(s):");],
[#NormalTok("               Effect        se         Z         p");],
[#NormalTok("self_esteem    0.3565    0.0829    4.2994    0.0000");],
[],
[#NormalTok("******************** ANALYSIS NOTES AND ERRORS ************************ ");],
[],
[#NormalTok("Level of confidence for all confidence intervals in output: 95");],));
]
]
Here is an output of our mediation using Sobel's test. You can see that it gives a #emph[p]-value of not just the individual paths, but of the indirect and direct paths overall. Our indirect effect is significant (z = 4.299, #emph[p] \< .001), while our direct effect is not (z = .367, #emph[p] = .719) - suggesting a full mediation, as we saw before.

Note that the output helpfully adds a note stating that the "Normal theory test" was used, which corresponds to Sobel's test.

Sobel's test is probably the most common method used, at least in most recent psychological literature. However, it too has a noticeable problem in that #strong[it only works well in large samples]. This is for a couple of reasons, but primarily that the distribution of #emph[ab] is only normal at very large sample sizes. Therefore, using Sobel's test in smaller sample sizes is likely to be skewed, which leads to #strong[incorrect standard errors].

=== Bootstrapping
<bootstrapping>
To overcome the problem described above, another approach is to #strong[bootstrap the standard errors]. This is where we continually resample a large number of times from our original dataset and calculate #emph[ab] for each sampled dataset. Once we do this enough times, we can build an empirical distribution of possible #emph[ab] values, and then use that to calculate an empirical #emph[p]-value for each effect.

The advantage of bootstrapping is that we can calculate more robust confidence intervals around our estimates without needing to assume normality - instead, these are directly derived from our data (in a sense). To that effect, here is an output from a #emph[bootstrapped] mediation (specifically, a bias-corrected bootstrapping method). A couple of extra notes here:

- #NormalTok("bc = 1"); means we want bias-corrected bootstrap intervals.
- #NormalTok("boot = 1000"); means that we want to bootstrap/resample 1000 times. While this is ok for now (and relatively fast), depending on the data you may want to up this to 10000 or higher.
- #NormalTok("seed = 2024"); sets a #emph[seed] for this run. Because bootstrapping involves random sampling, every run will give slightly different results (which isn't good for replicability/transparency). Setting a seed locks R into generating the same values on every run.

#block[
#Skylighting(([#NormalTok("med_bootstrap ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("process");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("data =");#NormalTok(" med_data,");],
[#NormalTok("  ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"happiness\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"grade\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("m =");#NormalTok(" ");#StringTok("\"self_esteem\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("model =");#NormalTok(" ");#DecValTok("4");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("bc =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("boot =");#NormalTok(" ");#DecValTok("1000");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("seed =");#NormalTok(" ");#DecValTok("2024");],
[#NormalTok(")");],));
]
#block[
#Skylighting(([#FunctionTok("print");#NormalTok("(med_bootstrap)");],));
#block[
#Skylighting(([#NormalTok("NULL");],));
]
]
Note that what changes here is the SE and confidence interval around each effect's estimate. We can see that the 95% confidence interval \[.224, .538\] is different to what we observed in the Sobel test version of this analysis. These are likely to be more robust, and thus we generally will want to prefer bootstrapping when running mediations.

== Moderation: Introduction
<moderation-introduction>
#block(fill: rgb("#f5f5f5"))[
We start the second half of this module with an overview of what moderation is, and how it can be used. On the next page we will go through a worked example.

]
=== Refresher on interactions
<refresher-on-interactions>
If you have completed the module on factorial ANOVAs, you'll be familiar with the concept of an interaction:

#quote(block: true)[
where the effect of one IV depends on the effect of another IV.
]

At the time we dealt with interactions between categorical predictors, i.e.~variables with discrete, defined and mutually exclusive groupings in the data - e.g.~sex (male, female) vs treatment (drug, placebo). We essentially estimate mean scores for each combination of categories in our data, and compare the variouos combinations on our continuous outcome measure, leading to graphs like these:

#align(center)[#box(image("img/interaction_cat.svg"))]
However, one thing we haven't looked at in great detail are interaction effects between #emph[continuous] predictors.

=== Moderation
<moderation>
#strong[Moderation] occurs when one variable influences the relationship between a predictor (X) and an outcome (Y). In contrast to a mediator, which we denote as M, we typically denote a moderator using W. Put simply, the existence of a moderator implies that the effect of X on Y depends on the value of W.

#align(center)[#box(image("img/moderation_1.png"))]
That might sound familiar… and for good reason! If you thought that just sounds like an interaction effect, you'd be absolutely right. At a statistical/mathematical level, a moderation is simply an interaction between two continuous predictors, and thus you can think of moderation and interaction as the same thing. That means that we can define a moderation using a regression formula as follows:

$ y = beta_0 + beta_1 x + beta_2 w + beta_3 \( x w \) + epsilon.alt_i $

Where $beta_1$ and $beta_2$ and are regression coefficients (slopes) for X and W respectively, and $beta_3$ is the interaction effect.

However, you may have already clocked that this may not be as easy as it may be for a factorial ANOVA, where we deal with categorical predictors. After all, at least in the categorical instance we could group observations based on the combinations of the two predictors. For example, in a factorial ANOVA with sex as one of the variables, we could plot/test an effect between a predictor and an outcome for men and women separately. But how do we do this for continuous variables, where there are no 'clear' cutpoints? To unpack a moderation, there are two techniques we can apply.

=== Simple slopes
<simple-slopes>
The first approach is the #strong[simple slopes] approach, which is similar in principle to simple effects tests after factorial ANOVAs. The basic idea of a simple slopes test is to calculate the predicted values between X and Y, for multiple levels of the moderator W. The standard approach is to take the mean value of the moderator W, as well as 1 SD above and below the mean, and calculate the regression slopes for each level of the moderator. We can then plot this as follows:

#align(center)[#box(image("img/interaction_plot.svg"))]
From this graph, we can infer the nature of the interaction. In this example, for participants high on the moderator (red line), the relationship between X and Y is stronger; consequently, for participants low on the moderator (blue line), participants show a weaker relationship.

Of course, we can also choose more points, e.g.~if we also wanted to look at +/- 2SD, or at percentile-based cutpoints we could do so.

=== The Johnson-Neyman technique
<the-johnson-neyman-technique>
A critique of the simple slopes, or "pick-a-point" approach is that the selected points are relatively arbitrary. While +/- 1SD make sense as cutpoints, we tend to choose those in the absence of anything especially meaningful or precise. A second technique for probing a continuous interaction/moderation is called the #strong[Johnson-Neyman] (JN) technique. The basic idea of the Johnson-Neyman technique is that it identifies the point at which the #strong[moderator] no longer significantly interacts with the predictor.

The exact maths behind this is complex, but in short it aims to identify the values of W that are equal to or below a critical #emph[t] value for a significant interaction effect.

We visualise the results of the Johnson-Neyman technique with a plot, which plots values of the moderator (W) on the x-axis against the #emph[slope] of the predictor on the y-axis. Here's an example (from the help docs for the interactions package in R:

#align(center)[#box(image("img/j-n-plot-1.png"))]
The red shaded region indicates where the moderation is non-significant. So, in this instance, values of the moderator between \~ 3.8 and 5.9 (as an eyeball guess) do not significantly moderate the relationship between the predictor and outcome. Values above or below this, however, do indicate significant moderation. Using the PROCESS macro in SPSS/R, it's possible to get the exact values for where this range starts and ends.

== Moderation: Example
<moderation-example>
#block(fill: rgb("#f5f5f5"))[
To round this module off, here is a worked example of a moderation.

]
=== Example scenario
<example-scenario-1>
We will use the dataset from Powell et al.~(2022) in the Week 10 seminar, which looks at harmonious and obsessive passion in the context of heavy metal music listeners. We'll test a specific question for this example: Do positive experiences predict harmonious passion, and does satisfaction with life moderate this relationship?

#block[
#Skylighting(([#NormalTok("passion_data ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"week_10\"");#NormalTok(", ");#StringTok("\"W10_Powell_2022.csv\"");#NormalTok("))");],));
]
=== Setting up in R
<setting-up-in-r>
To set up a moderation using PROCESS, we turn to the #NormalTok("process()"); function once again. This time, we want to set the following options:

- #NormalTok("w"); sets our moderator.
- #NormalTok("model = 1"); indicates that we want a simple moderation.
- #NormalTok("plot = 1"); gives us values for plotting the moderation.
- #NormalTok("jn = 1"); calculates the Johnson-Neyman values for a significant moderation. These are also used for plotting.
- #NormalTok("save = 2"); is used to save the output to a variable.

#block[
#Skylighting(([#NormalTok("passion_mod ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("process");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("data =");#NormalTok(" passion_data,");],
[#NormalTok("  ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"HP_TOT\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"SPANE_pos\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("w =");#NormalTok(" ");#StringTok("\"SWLS_TOT\"");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("model =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("plot =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("jn =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("save =");#NormalTok(" ");#DecValTok("2");],
[#NormalTok(")");],));
]
=== Output
<output-11>
Let's now take a look at our output. The first output is our overall model fit, which is identical to what we get for any other multiple regression. Our model in this instance is significant, and explains 19.6% of the variance in harmonious passion.

The second output gives us our standard regression table. This tells us whether the moderation is significant, and we can interpret this as we would for any other regression we've seen. So, here we can see that positive experiences are a significant predictor of harmonious passion (B = 0.796, t = 6.290, p \< .001), but satisfaction with life is not (p = .279). However, the interaction - or moderation - between the two is significant (B = 0.036, t = 2.576, p = .011).

#block[
#block[
#Skylighting(([],
[#NormalTok("**************** PROCESS Procedure for R Version 5.0 ****************** ");],
[#NormalTok(" ");],
[#NormalTok("           Written by Andrew F. Hayes, Ph.D.  www.afhayes.com              ");],
[#NormalTok("   Documentation available in Hayes (2022). www.guilford.com/p/hayes3   ");],
[#NormalTok(" ");],
[#NormalTok("*********************************************************************** ");],
[#NormalTok("                  ");],
[#NormalTok("  Model: 1        ");],
[#NormalTok("      Y: HP_TOT   ");],
[#NormalTok("      X: SPANE_pos");],
[#NormalTok("      W: SWLS_TOT ");],
[],
[#NormalTok("Sample size: 177");],
[],
[],
[#NormalTok("*********************************************************************** ");],
[#NormalTok("Outcome Variable: HP_TOT");],
[],
[#NormalTok("Model Summary: ");],
[#NormalTok("          R      R-sq       MSE         F       df1       df2         p");],
[#NormalTok("     0.4425    0.1958   32.2539   14.0427    3.0000  173.0000    0.0000");],
[],
[#NormalTok("Model: ");],
[#NormalTok("              coeff        se         t         p      LLCI      ULCI");],
[#NormalTok("constant    26.4430    5.7267    4.6175    0.0000   15.1398   37.7462");],
[#NormalTok("SPANE_pos    0.0960    0.2529    0.3796    0.7047   -0.4031    0.5951");],
[#NormalTok("SWLS_TOT    -0.8896    0.3329   -2.6723    0.0083   -1.5466   -0.2325");],
[#NormalTok("int_1        0.0358    0.0139    2.5757    0.0108    0.0084    0.0632");],
[],
[#NormalTok("Product terms key:");],
[#NormalTok("int_1  :  SPANE_pos  x  SWLS_TOT      ");],
[],
[#NormalTok("Test(s) of highest order unconditional interaction(s):");],
[#NormalTok("      R2-chng         F       df1       df2         p");],
[#NormalTok("X*W    0.0308    6.6341    1.0000  173.0000    0.0108");],
[#NormalTok("----------");],
[#NormalTok("Focal predictor: SPANE_pos (X)");],
[#NormalTok("      Moderator: SWLS_TOT (W)");],
[],
[#NormalTok("Conditional effects of the focal predictor at values of the moderator(s):");],
[#NormalTok("   SWLS_TOT    effect        se         t         p      LLCI      ULCI");],
[#NormalTok("    12.0000    0.5256    0.1305    4.0288    0.0001    0.2681    0.7831");],
[#NormalTok("    20.0000    0.8120    0.1290    6.2931    0.0000    0.5573    1.0666");],
[#NormalTok("    28.0000    1.0984    0.2025    5.4242    0.0000    0.6987    1.4980");],
[],
[#NormalTok("Moderator value(s) defining Johnson-Neyman significance region(s):");],
[#NormalTok("      Value   % below   % above");],
[#NormalTok("     6.8962    4.5198   95.4802");],
[],
[#NormalTok("Conditional effect of focal predictor at values of the moderator:");],
[#NormalTok("   SWLS_TOT    effect        se         t         p      LLCI      ULCI");],
[#NormalTok("     5.0000    0.2750    0.1940    1.4176    0.1581   -0.1079    0.6579");],
[#NormalTok("     6.5000    0.3287    0.1778    1.8485    0.0662   -0.0223    0.6796");],
[#NormalTok("     6.8962    0.3429    0.1737    1.9738    0.0500    0.0000    0.6857");],
[#NormalTok("     8.0000    0.3824    0.1627    2.3500    0.0199    0.0612    0.7035");],
[#NormalTok("     9.5000    0.4361    0.1490    2.9264    0.0039    0.1420    0.7302");],
[#NormalTok("    11.0000    0.4898    0.1371    3.5717    0.0005    0.2191    0.7604");],
[#NormalTok("    12.5000    0.5435    0.1276    4.2606    0.0000    0.2917    0.7952");],
[#NormalTok("    14.0000    0.5972    0.1209    4.9410    0.0000    0.3586    0.8357");],
[#NormalTok("    15.5000    0.6509    0.1175    5.5379    0.0000    0.4189    0.8829");],
[#NormalTok("    17.0000    0.7046    0.1179    5.9785    0.0000    0.4720    0.9372");],
[#NormalTok("    18.5000    0.7583    0.1218    6.2259    0.0000    0.5179    0.9987");],
[#NormalTok("    20.0000    0.8120    0.1290    6.2931    0.0000    0.5573    1.0666");],
[#NormalTok("    21.5000    0.8657    0.1390    6.2263    0.0000    0.5912    1.1401");],
[#NormalTok("    23.0000    0.9194    0.1513    6.0776    0.0000    0.6208    1.2179");],
[#NormalTok("    24.5000    0.9731    0.1652    5.8887    0.0000    0.6469    1.2992");],
[#NormalTok("    26.0000    1.0268    0.1805    5.6871    0.0000    0.6704    1.3831");],
[#NormalTok("    27.5000    1.0805    0.1969    5.4883    0.0000    0.6919    1.4690");],
[#NormalTok("    29.0000    1.1342    0.2140    5.3004    0.0000    0.7118    1.5565");],
[#NormalTok("    30.5000    1.1879    0.2317    5.1267    0.0000    0.7305    1.6452");],
[#NormalTok("    32.0000    1.2416    0.2499    4.9681    0.0000    0.7483    1.7348");],
[#NormalTok("    33.5000    1.2953    0.2685    4.8241    0.0000    0.7653    1.8252");],
[#NormalTok("    35.0000    1.3489    0.2874    4.6937    0.0000    0.7817    1.9162");],));
]
#block[
#Skylighting(([],
[#NormalTok("Data for visualizing the conditional effect of the focal predictor:");],
[#NormalTok("  SPANE_pos  SWLS_TOT    HP_TOT");],
[#NormalTok("    19.0000   12.0000   25.7538");],
[#NormalTok("    23.0000   12.0000   27.8561");],
[#NormalTok("    27.0000   12.0000   29.9584");],
[#NormalTok("    19.0000   20.0000   24.0785");],
[#NormalTok("    23.0000   20.0000   27.3264");],
[#NormalTok("    27.0000   20.0000   30.5742");],
[#NormalTok("    19.0000   28.0000   22.4032");],
[#NormalTok("    23.0000   28.0000   26.7966");],
[#NormalTok("    27.0000   28.0000   31.1900");],));
]
#block[
#Skylighting(([],
[#NormalTok("******************** ANALYSIS NOTES AND ERRORS ************************ ");],
[],
[#NormalTok("Level of confidence for all confidence intervals in output: 95");],
[],
[#NormalTok("W values in conditional tables are the 16th, 50th, and 84th percentiles.");],));
]
]
This indicates that we should investigate further, first with our simple slope/interaction plot as below. Unfortunately, as you can tell, the #NormalTok("plot"); argument in #NormalTok("process()"); doesn't actually generate any plots. Rather, it gives a series of values for the predictor, moderator and outcome to plot. The same applies for the output from the Johnson-Neyman technique - while the output does tell you where the moderation is/is not significant, it does not draw a plot. This is probably because PROCESS was designed for SPSS users first and foremost in mind, and the SAS and R versions were designed for parity for SPSS first and foremost (rather than designed to take advantage of their native capabilities).

There are ways to use these values for plotting, but truthfully - at least for this subject - they are far more effort than they are worth. Rather, there is a great package called #NormalTok("interactions"); that will draw these plots for us.

To start, we use #NormalTok("lm()"); to build a regular regression model with an interaction between our predictor and moderator:

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(interactions)");],
[#NormalTok("passion_mod_lm ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(HP_TOT ");#SpecialCharTok("~");#NormalTok(" SPANE_pos ");#SpecialCharTok("*");#NormalTok(" SWLS_TOT, ");#AttributeTok("data =");#NormalTok(" passion_data)");],));
]
The #NormalTok("interact_plot()"); function will then draw us a standard plot with simple slopes, based on the model above. For this function to work, at a minimum you must give it a) the name of the #NormalTok("lm()"); model, b) the name of the predictor to #NormalTok("pred"); and c) the name of the moderator to #NormalTok("modx");. The #NormalTok("colors"); argument has also been specified to change the colours for the lines (by default they are different shades of blue).

Based on the below graph, we can see that in all instances, the relationship between positive experiences and harmonious passion is positive. However, for people who are high on satisfaction with like (Mean + 1SD), the relationship is stronger - indexed by a greater slope. This relationship is weaker for people who are low on satisfaction with life (Mean - 1SD).

#Skylighting(([#FunctionTok("interact_plot");#NormalTok("(passion_mod_lm, ");],
[#NormalTok("              ");#AttributeTok("pred =");#NormalTok(" ");#StringTok("\"SPANE_pos\"");#NormalTok(",");],
[#NormalTok("              ");#AttributeTok("modx =");#NormalTok(" ");#StringTok("\"SWLS_TOT\"");#NormalTok(", ");],
[#NormalTok("              ");#AttributeTok("colors =");#NormalTok(" ");#StringTok("\"Set1\"");#NormalTok(") ");],));
#box(image("12-medmod_files/figure-typst/unnamed-chunk-21-1.svg"))

Lastly, we can examine the Johnson-Neyman plots to see where this relationship is non-significant. The same basic set of arguments - model, predictor, and moderator - can also be used as is for the #NormalTok("johnson_neyman()"); function, which will draw a Johnson-Neyman plot. Helpfully, the function will also give a brief summary of the regions of significance/non-significance. Based on the plot and the text output, the moderation is non-significant when the moderator (satifaction with life) is below 6.9.

#Skylighting(([#FunctionTok("johnson_neyman");#NormalTok("(passion_mod_lm, ");#AttributeTok("pred =");#NormalTok(" ");#StringTok("\"SPANE_pos\"");#NormalTok(", ");#AttributeTok("modx =");#NormalTok(" ");#StringTok("\"SWLS_TOT\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("JOHNSON-NEYMAN INTERVAL");],
[],
[#NormalTok("When SWLS_TOT is OUTSIDE the interval [-65.76, 6.90], the slope of");],
[#NormalTok("SPANE_pos is p < .05.");],
[],
[#NormalTok("Note: The range of observed values of SWLS_TOT is [5.00, 35.00]");],));
]
#box(image("12-medmod_files/figure-typst/unnamed-chunk-22-1.svg"))

= Non-parametric tests
<nonpara>
So far, we have (almost) exclusively dealt in what we consider #emph[parametric] tests. Our classic body of tests like the #emph[t]-test, ANOVA and regression model, and their extensions, are all forms of parametric statistical models. However, we have also seen that these tests are all accompanied with (and to some extent, defined or constrained by) certain assumptions about the data. If these assumptions are violated to a severe enough extent, we may need to adjust our modelling approach to match.

One option is to turn to statistical tests that are similar to the ones we know, but do #emph[not] make the all of the same assumptions. These broadly form the suite of #strong[non-parametric] tests, which we will focus on here. In this section we will focus on non-parametric alternatives to correlations, #emph[t]-tests and ANOVAs.

Technically speaking, we have already come across one family of non-parametric tests: chi-squares! We will expand on more why as we go through. Also, while there is a technique called non-parametric regression it is #emph[very] different to normal regression and so will not be discussed here.

== Parametric vs non-parametric tests
<parametric-vs-non-parametric-tests>
=== Introduction
<introduction-7>
Recall the aim of much of the statistics we do:

#align(center)[#box(image("img/populations_samples.svg"))]
When we estimate these parameters using statistical tests, we make certain assumptions about data in order for our tests to be valid. Many of those assumptions involve some degree of normality - whether the data/outcome needs to be normally distributed, or the residuals in the model need to be normally distributed. The tests that we cover in this subject - #emph[t]-tests and ANOVAs especially - are called parametric tests, because they make an assumption about the distribution. But what happens if those assumptions aren't met?

=== Non-parametric tests
<non-parametric-tests>
Non-parametric tests do not make assumptions about the underlying distributions of data (and hence are sometimes called distribution-free tests). Instead, they are more general tests that make the following (broad) hypotheses:

- $H_0$: The underlying distributions are equal
- $H_1$: The underlying distributions are not equal

So when should they be used, and what are their pros and cons? In general, non-parametric tests should be considered when a) #strong[assumptions for parametric tests are not met] and b) #strong[you are working with small samples]. As noted below, with large samples a lot of the parametric assumptions in tests are fairly robust (unless deviations are particularly severe).

Below are the non-parametric equivalents to the major tests that we cover, with their associated datasets.

#table(
  columns: 2,
  align: (left,left,),
  table.header([Parametric test], [Non-parametric equivalent],),
  table.hline(),
  [Pearson's r], [Spearman's rho],
  [Independent samples t-test], [Mann-Whitney U test],
  [Paired samples t-test], [Wilcoxon signed-rank test],
  [One-way ANOVA], [Kruskal-Wallis ANOVA],
  [One-way repeated measures ANOVA], [Friedman ANOVA],
)
== Spearman's rho
<spearmans-rho>
=== Introduction
<introduction-8>
Spearman's rho ($rho$) is a non-parametric correlation coefficient, broadly equivalent in interpretation with Pearson's correlation coefficient. It is used to calculate a correlation in instances where Pearson's r would not be appropriate; namely, when data is not linear.

Spearman's rho can be used when data is monotonic. Monotonic data is data where as X changes, Y changes in one direction. Below is a visualisation of monotonic versus non-monotonic data:

#box(image("13-nonpara_files/figure-typst/unnamed-chunk-3-1.svg"))

In the linear and monotonic examples, the line of best fit follows one direction - up. In the rightmost graph, however, there is a decrease and then an increase in the predicted values of y. This is an example of a non-monotonic function.

=== Understanding ranks
<understanding-ranks>
Non-parametric statistics, including all of the ones that we talk about in this module, rely on establishing ranks in your data. Mathematically, this is how non-parametric tests are able to test the hypotheses they do without needing to rely on accurately estimating some parameter, or making assumptions about said parameters. Although each test has a different way of using these ranks, many of them often start by calculating ranks in your data.

This is about as simple as it sounds. Consider the table below, with 5 measurements on a simple scale. The left column shows the raw data, while the middle column shows the ranked data - largest to smallest, reading top to bottom. The right column shows their ranks in order. The smallest value is given a rank of 1.

The ranks are then used to calculate test statistics for non-parametric tests.

=== Example
<example-10>
Below is a simple example of a correlation between two variables where non-linearity may be important. Singing accuracy is naturally skewed heavily, and develops non-linearly throughout life.

#block[
#Skylighting(([#NormalTok("singing ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"nonpara\"");#NormalTok(", ");#StringTok("\"singing_data.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 284 Columns: 2");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("dbl (2): accuracy, age");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
The relevant dataset contains just two variables: accuracy (measured in cents) and age (participant age). The scatterplot below shows the relationship between these two variables:

#Skylighting(([#NormalTok("singing ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" age, ");#AttributeTok("y =");#NormalTok(" accuracy)");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ggpubr");#SpecialCharTok("::");#FunctionTok("theme_pubr");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("()");],));
#box(image("13-nonpara_files/figure-typst/unnamed-chunk-5-1.svg"))

To calculate Spearman's rho, the steps are much the same as the way they are for normal correlations - we use the same #NormalTok("cor.test()"); function that we saw earlier. The main difference is that we now must specify the #NormalTok("method"); argument to equal to #NormalTok("\"spearman\"");, which will calculate Spearman's rho instead.. Here, we see results consistent with a Pearson's correlation; a significant, positive association between age and accuracy ($rho$ = .53, #emph[p] \< .001).

#block[
#Skylighting(([#FunctionTok("cor.test");#NormalTok("(singing");#SpecialCharTok("$");#NormalTok("accuracy, singing");#SpecialCharTok("$");#NormalTok("age, ");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"spearman\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Warning in cor.test.default(singing$accuracy, singing$age, method =");],
[#NormalTok("\"spearman\"): Cannot compute exact p-value with ties");],));
]
#block[
#Skylighting(([],
[#NormalTok("    Spearman's rank correlation rho");],
[],
[#NormalTok("data:  singing$accuracy and singing$age");],
[#NormalTok("S = 1808559, p-value < 2.2e-16");],
[#NormalTok("alternative hypothesis: true rho is not equal to 0");],
[#NormalTok("sample estimates:");],
[#NormalTok("      rho ");],
[#NormalTok("0.5262664 ");],));
]
]
== Mann-Whitney U tests
<mann-whitney-u-tests>
=== Introduction
<introduction-9>
A Mann-Whitney U (also called a #strong[Wilcoxon rank-sum test]) is a non-parametric form of the independent samples t-test. In other words, it applies to situations where you are comparing two independent groups, and for whatever reason the assumptions of an independent t-test are severely violated.

Note that many statistics webpages erroneously call the Mann-Whitney U a test of medians; this is not necessarily true (and even the distribution point is a little strained). The test is simply on the ranks of the data.

=== Hypotheses
<hypotheses>
- $H_0$: The probability distributions of the two groups is the same (i.e.~they derive from the same distribution).
- $H_1$: The probability distributions of the two groups are not the same (i.e.~they derive from different distribution).

The test statistic is the #strong[U] statistic. The U statistic ranges from 0 (which implies complete separation between the two groups) and n1 \* n2 (the sample sizes of both groups multiplied).

=== Example
<example-11>
The dataset for this page and the next relate to young men's wages in 1980 and 1987 across the United States. The original study was interested in the effects of union bargaining/membership on wages.

The following variables are in the dataset:

- nr: Participant ID
- year: year of measurement (1980 or 1987)
- school: Years of schooling
- exper: Years of work experience, calculated as school - 6
- union: Was their wage set by collective bargaining? (two levels: yes, no)
- ethn: Participant ethnicity (three levels: black, hisp, other)
- married; Marital status (two levels: yes, no)
- health: Does the participant have a health problem? (two levels: yes, no)
- wage: Hourly wage, log-transformed
- industry, occupation, residence: Demographic and descriptive variables

#block[
#Skylighting(([#NormalTok("wages ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"nonpara\"");#NormalTok(", ");#StringTok("\"wages.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 1090 Columns: 13");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (7): union, ethn, married, health, industry, occupation, residence");],
[#NormalTok("dbl (6): ...1, nr, year, school, exper, wage");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
Consider the following question: In 1980, were wages higher for union members than non-union members?

Let's take a look at the data in R first. First, let's filter our dataset so that we only have cases from 1980.

#block[
#Skylighting(([#NormalTok("wages_1980 ");#OtherTok("<-");#NormalTok(" wages ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(year ");#SpecialCharTok("==");#NormalTok(" ");#DecValTok("1980");#NormalTok(")");],));
]
Pretend that we run our assumption checks on the wage data and obtain the following:

#block[
#Skylighting(([#NormalTok("wages_1980 ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(union) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("shapiro_test");#NormalTok("(wage)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 2 × 4");],
[#NormalTok("  union variable statistic        p");],
[#NormalTok("  <chr> <chr>        <dbl>    <dbl>");],
[#NormalTok("1 no    wage         0.932 1.14e-12");],
[#NormalTok("2 yes   wage         0.976 1.81e- 2");],));
]
]
#block[
#Skylighting(([#NormalTok("wages_1980 ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("levene_test");#NormalTok("(wage ");#SpecialCharTok("~");#NormalTok(" union, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Warning in leveneTest.default(y = y, group = group, ...): group coerced to");],
[#NormalTok("factor.");],));
]
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 4");],
[#NormalTok("    df1   df2 statistic        p");],
[#NormalTok("  <int> <int>     <dbl>    <dbl>");],
[#NormalTok("1     1   543      11.0 0.000972");],));
]
]
Both assumptions have been violated. Now, pretend that we think this violation is bad enough that even a Welch test wouldn't be appropriate. In this instance, we may turn to a Mann-Whitney U test.

=== Output
<output-12>
TO run a Mann-Whitney U test, we use the #NormalTok("wilcox.test()"); function in R. The #NormalTok("wilcox.test()"); function behaves just like the regular #NormalTok("t.test()"); function for both independent and paired-samples #emph[t]-tests, down to the same notation. So, we can use the same notation for a independent-samples #emph[t]-test as we have done so in the past:

#block[
#Skylighting(([#FunctionTok("wilcox.test");#NormalTok("(wage ");#SpecialCharTok("~");#NormalTok(" union, ");#AttributeTok("data =");#NormalTok(" wages_1980)");],));
#block[
#Skylighting(([],
[#NormalTok("    Wilcoxon rank sum test with continuity correction");],
[],
[#NormalTok("data:  wage by union");],
[#NormalTok("W = 19767, p-value = 2.898e-07");],
[#NormalTok("alternative hypothesis: true location shift is not equal to 0");],));
]
]
Here is our output above. We can see that the #emph[p]-value is significant, and so therefore these two samples (union vs non-union) do not appear to come from the same underlying distribution (Mann-Whitney #emph[U] = 19767, #emph[p] \< .001). We can then use descriptives as per normal to figure out where the difference is (the median and mean wages for union members are higher than non-members).

We also want to calculate our effect size for this test, called the #strong[rank biserial correlation]. We won't worry too much about the maths here, but we can broadly interpret this along similar lines to Pearson's r (weak to medium in this instance). To do this, we can use the #NormalTok("rank_biserial()"); function in the #NormalTok("effectsize"); package, which works like its #NormalTok("cohens_d()"); counterpart:

#block[
#Skylighting(([#FunctionTok("rank_biserial");#NormalTok("(wage ");#SpecialCharTok("~");#NormalTok(" union, ");#AttributeTok("data =");#NormalTok(" wages_1980)");],));
#block[
#Skylighting(([#NormalTok("r (rank biserial) |         95% CI");],
[#NormalTok("----------------------------------");],
[#NormalTok("-0.29             | [-0.39, -0.19]");],));
]
]
Something to note, though, is that unlike the standard #emph[t]-test, how exactly this result should be interpreted is a little more vague. With a regular #emph[t]-test, we test differences between two group means, and thus we can directly make a comparison between means when interpreting a test. In this instance, however, we are testing differences in #emph[ranks]\; this doesn't have a clean interpretation beyond there just being a difference (of sorts) between the groups.

== Wilcoxon signed rank test
<wilcoxon-signed-rank-test>
=== Introduction
<introduction-10>
The non-parametric equivalent to the paired-samples #emph[t]-test is the Wilcoxon signed-rank test. The sign and rank part of the test's name comes from how the test statistic is calculated. We won't deal too much with the mechanics of doing this, but it involves three main steps:

+ Calculate the difference between condition 1 and condition 2
+ Rank each difference based on its absolute value (i.e.~disregard whether it is positive/negative)
+ Add up each set of signed differences (i.e.~add all the positive differences together, and add all the negative ones together). The test statistic is the minimum of the two.

In essence, the maths is exactly the same as a regular paired-samples #emph[t]-test (i.e.~it is a one-sample test on the differences between groups), but just using ranks this time rather than means. The Wilcoxon signed-rank test can be used to test whether the medians differ between the two conditions (i.e.~it's appropriate to hypothesise this here). Like the other non-parametric tests, it is a test that is free from assumptions about distributions.

=== Example
<example-12>
In the wages dataset, there are wages between 1980 and 1987. Did the median wage change between these two years? Here are our descriptives:

#block[
#Skylighting(([#NormalTok("wages_wide ");#OtherTok("<-");#NormalTok(" wages ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(nr, year, wage) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pivot_wider");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("id_cols =");#NormalTok(" nr,");],
[#NormalTok("    ");#AttributeTok("names_from =");#NormalTok(" year,");],
[#NormalTok("    ");#AttributeTok("values_from =");#NormalTok(" wage,");],
[#NormalTok("    ");#AttributeTok("names_prefix =");#NormalTok(" ");#StringTok("\"wage_\"");],
[#NormalTok("  )");],));
]
Recall that in a paired-samples #emph[t]-test, the normality assumption refers to whether the differences between the two conditions are normally distributed. We can test this in the usual two ways: 1) with a normality significance test, and 2) by assessing a Q-Q plot. Here is the former, to show what a non-normal dataset might look like:

#block[
#Skylighting(([#FunctionTok("shapiro.test");#NormalTok("(wages_wide");#SpecialCharTok("$");#NormalTok("wage_1980 ");#SpecialCharTok("-");#NormalTok(" wages_wide");#SpecialCharTok("$");#NormalTok("wage_1987)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  wages_wide$wage_1980 - wages_wide$wage_1987");],
[#NormalTok("W = 0.88454, p-value < 2.2e-16");],));
]
]
As we can see, the test is significant (Shapiro-Wilks' #emph[W] = .885, #emph[p] \< .001) - naturally, a tell-tale sign that this data aren't normally distributed. This would be a good example to use Wilcoxon signed-rank tests over a regular paired t-test.

=== Output
<output-13>
The setup for a signed-rank test in R again uses the same syntax as the regular #NormalTok("t.test()"); function for a paired test - meaning that we can either give it the two separate columns with #NormalTok("paired = TRUE");, or use #NormalTok("Pairs(a, b) ~ 1"); notation. For simplicity we'll just do the former:

#block[
#Skylighting(([#FunctionTok("wilcox.test");#NormalTok("(wages_wide");#SpecialCharTok("$");#NormalTok("wage_1980, wages_wide");#SpecialCharTok("$");#NormalTok("wage_1987, ");#AttributeTok("paired =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("    Wilcoxon signed rank test with continuity correction");],
[],
[#NormalTok("data:  wages_wide$wage_1980 and wages_wide$wage_1987");],
[#NormalTok("V = 15096, p-value < 2.2e-16");],
[#NormalTok("alternative hypothesis: true location shift is not equal to 0");],));
]
]
As mentioned on the previous page, we can also use our #NormalTok("rank_biserial()"); function the same way to calculate an effect size for this paired test:

#block[
#Skylighting(([#FunctionTok("rank_biserial");#NormalTok("(wages_wide");#SpecialCharTok("$");#NormalTok("wage_1980, wages_wide");#SpecialCharTok("$");#NormalTok("wage_1987, ");#AttributeTok("paired =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("r (rank biserial) |         95% CI");],
[#NormalTok("----------------------------------");],
[#NormalTok("-0.80             | [-0.83, -0.76]");],));
]
]
Here is our output. Our test is clearly significant, so we can reject the null and say that wages in 1987 were higher than wages in 1980 (#emph[W] = 15096, #emph[p] \< .001). Our effect size is also large this time (and negative, indicating that wages were higher in 1987 than 1980).

== Kruskal-Wallis ANOVA
<kruskal-wallis-anova>
=== Introduction
<introduction-11>
The Kruskal-Wallis ANOVA is the non-parametric equivalent of the basic one-way ANOVA. It is essentially an extension of the Mann-Whitney U test, which has a couple of important ramifications: namely, it doesn't assume any underlying distributions.

Like the Mann-Whitney U test, by default the Kruskal-Wallis ANOVA is purely a test of whether the data in each group come from the same underlying distributions. The KW ANOVA can only test for a difference in medians if you can assume that each group's distribution is the same shape and spread (e.g.~all groups are skewed in the same way). Otherwise, you are essentially testing for a difference in the underlying distributions.

=== Example scenario
<example-scenario-2>
The example data for this page and the next come from one data source, looking at language abilities in young children. These datasets contain the same participants, but the file labelled "autism\_kw" takes data at one cross-section while the "autism\_friedman" file contains four timepoints.

The variables in this dataset include:

- childid: Participant ID

- sicdegp: Assessment of expressive language development. Three groups: high, medium, low.

- age2: Participant's age, centered around 2 years old. The numeric values indicate how many years have passed since the child was 2 years old.

- #Skylighting(([#NormalTok("   In the \"autism_friedman\" dataset, the columns are labelled age_0, age_1, age_3 and age_7. These refer to the ages of 2 years old, 2yo, 5yo and 9yo respectively.");],));

- vsae: Vineland Socialisation Age Equivalent

- gender, race: Participant's gender and race

- bestest2 - Diagnosis at age 2. Two levels: autism and PDD (pervasive developmental disorder).

We will take a look at the first autism dataset ("autism\_kw"). In this dataset, we want to conduct an ANOVA comparing socialisation age equivalents (VSAE) between children with varying levels of expressive language development.

#block[
#Skylighting(([#NormalTok("autism ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"nonpara\"");#NormalTok(", ");#StringTok("\"autism_long.csv\"");#NormalTok(")) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("sicdegp =");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(sicdegp)");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok("Rows: 63 Columns: 7");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (4): sicdegp, gender, race, bestest2");],
[#NormalTok("dbl (3): childid, age2, vsae");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
=== Checking assumptions (normal ANOVA)
<checking-assumptions-normal-anova>
Here's what a regular ANOVA would look like on this data - specifically, the assumption checks. We can see that both assumptions are violated; Levene's test is significant (#emph[F]\(2, 60) = 4.57, #emph[p] =. 014), and the Shaprio-Wilks test is too (backed up by a funky looking Q-Q plot; #emph[W] = .86, #emph[p] \< .001).

#block[
#Skylighting(([#NormalTok("autism_aov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov");#NormalTok("(vsae ");#SpecialCharTok("~");#NormalTok(" sicdegp, ");#AttributeTok("data =");#NormalTok(" autism)");],));
]
#block[
#Skylighting(([#CommentTok("# levene's test");],
[],
[#NormalTok("autism ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("levene_test");#NormalTok("(vsae ");#SpecialCharTok("~");#NormalTok(" sicdegp, ");#AttributeTok("center =");#NormalTok(" ");#StringTok("\"mean\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 4");],
[#NormalTok("    df1   df2 statistic      p");],
[#NormalTok("  <int> <int>     <dbl>  <dbl>");],
[#NormalTok("1     2    60      4.57 0.0142");],));
]
]
#block[
#Skylighting(([#CommentTok("# Shapiro-wilks");],
[],
[#FunctionTok("shapiro.test");#NormalTok("(autism_aov");#SpecialCharTok("$");#NormalTok("residuals)");],));
#block[
#Skylighting(([],
[#NormalTok("    Shapiro-Wilk normality test");],
[],
[#NormalTok("data:  autism_aov$residuals");],
[#NormalTok("W = 0.86118, p-value = 4.232e-06");],));
]
]
#Skylighting(([#NormalTok("autism_aov ");#SpecialCharTok("%>%");],
[#NormalTok("  broom");#SpecialCharTok("::");#FunctionTok("augment");#NormalTok("() ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("sample =");#NormalTok(" .std.resid)");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_qq");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_qq_line");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ggpubr");#SpecialCharTok("::");#FunctionTok("theme_pubr");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("Warning: The `augment()` method for objects of class `aov` is not maintained by the broom team, and is only supported through the `lm` tidier method. Please be cautious in interpreting and reporting broom output.");],
[],
[#NormalTok("This warning is displayed once per session.");],));
]
#box(image("13-nonpara_files/figure-typst/unnamed-chunk-21-1.svg"))

Now, these aren't too bad in general, but let's assume for the sake of practice that these violations are severe enough that we would consider using non-parametrics instead.

=== Output
<output-14>
To conduct a Kruskal-Wallis ANOVA in R, we can use the #NormalTok("kruskal.test()"); function. This function works very similarly to #NormalTok("aov()");, meaning that we can provide the same notation as we normally would:

#block[
#Skylighting(([#NormalTok("autism_kw ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("kruskal.test");#NormalTok("(vsae ");#SpecialCharTok("~");#NormalTok(" sicdegp, ");#AttributeTok("data =");#NormalTok(" autism)");],
[#NormalTok("autism_kw");],));
#block[
#Skylighting(([],
[#NormalTok("    Kruskal-Wallis rank sum test");],
[],
[#NormalTok("data:  vsae by sicdegp");],
[#NormalTok("Kruskal-Wallis chi-squared = 28.474, df = 2, p-value = 6.562e-07");],));
]
]
Note here that the test statistic in a Kruskal-Wallis is a chi-square distribution, with a df of #emph[g] - 1 (where #emph[g] = number of groups). This is sometimes called #emph[H], but is mathematically equivalent to the chi-square we are familiar with. Our overall result is significant ($chi^2$\(2) = 28.47, #emph[p] \< .001).

The same notation is used for calculating effect sizes, using the #NormalTok("rank_epsilon_squared()"); function from #NormalTok("effectsize");:

#block[
#Skylighting(([#FunctionTok("rank_epsilon_squared");#NormalTok("(vsae ");#SpecialCharTok("~");#NormalTok(" sicdegp, ");#AttributeTok("data =");#NormalTok(" autism)");],));
#block[
#Skylighting(([#NormalTok("Epsilon2 (rank) |       95% CI");],
[#NormalTok("------------------------------");],
[#NormalTok("0.46            | [0.35, 1.00]");],
[],
[#NormalTok("- One-sided CIs: upper bound fixed at [1.00].");],));
]
]
Here, our non-parametric effect size is epsilon squared, $epsilon.alt^2$. It is not commonly seen so can be hard to interpret, but people have made various guidelines of their own.

Jamovi uses Dwass-Steel-Critchlow-Fligner tests (phew!), or simply DCSF tests, for 'post hoc' pairwise comparisons. We'll use the same here for compatibility with Jamovi. The only thing you really need to know about these comparisons is that they have an in-built correction for the family-wise error rate, so do not need adjusting after the analyses have been run.

To run these tests, we need a new package called #NormalTok("PMCMRplus");. Within this package is a function called #NormalTok("dscfAllPairsTest()");, which will give us the #emph[p]-values for each pairwise comparison. The required code is exactly the same as we have used above:

#block[
#Skylighting(([#NormalTok("PMCMRplus");#SpecialCharTok("::");#FunctionTok("dscfAllPairsTest");#NormalTok("(vsae ");#SpecialCharTok("~");#NormalTok(" sicdegp, ");#AttributeTok("data =");#NormalTok(" autism)");],));
#block[
#Skylighting(([],
[#NormalTok("    Pairwise comparisons using Dwass-Steele-Critchlow-Fligner all-pairs test");],));
]
#block[
#Skylighting(([#NormalTok("data: vsae by sicdegp");],));
]
#block[
#Skylighting(([#NormalTok("    high    low   ");],
[#NormalTok("low 5.4e-06 -     ");],
[#NormalTok("med 0.0002  0.0635");],));
]
#block[
#Skylighting(([],
[#NormalTok("P value adjustment method: single-step");],));
]
]
We can see that there is a significant difference in socialisation age between children with high versus low expressive language (p \< .001), as well as between children with high versus medium expressive language (p \< .001). However, there is no significant difference in socialisation age between children with low and medium expressive language (p = .064).

== Friedman ANOVAs
<friedman-anovas>
=== Introduction
<introduction-12>
The Friedman ANOVA (or Friedman test) is the non-parametric equivalent of a one-way repeated measures ANOVA. The idea behind the Friedman's ANOVA is the same as its parametric counterpart, namely to test whether there are differences in treatments across multiple time points.

=== Example scenario
<example-scenario-3>
We will take a look at the autism dataset again, albeit with a new version called #NormalTok("autism_wide.csv");. In this scenario, we now want to see how expressive language changes over time. Note that the variables relating to age are referenced/centered to 2 years old. That is, a value of #NormalTok("age2"); of 0 indicates the child is 2 years old; a value of 1 refers to 3 years old and a value of 3 refers to 5 years old.

#block[
#Skylighting(([#NormalTok("autism_wide ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_csv");#NormalTok("(");#FunctionTok("here");#NormalTok("(");#StringTok("\"data\"");#NormalTok(", ");#StringTok("\"nonpara\"");#NormalTok(", ");#StringTok("\"autism_wide.csv\"");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("Rows: 63 Columns: 9");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("chr (4): sicdegp, gender, race, bestest2");],
[#NormalTok("dbl (5): childid, age_0, age_1, age_3, age_7");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
#Skylighting(([#CommentTok("# Reshape into long format");],
[],
[#NormalTok("autism ");#OtherTok("<-");#NormalTok(" autism_wide ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pivot_longer");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("cols =");#NormalTok(" age_0");#SpecialCharTok(":");#NormalTok("age_7,");],
[#NormalTok("    ");#AttributeTok("names_to =");#NormalTok(" ");#StringTok("\"age2\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("values_to =");#NormalTok(" ");#StringTok("\"vsae\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("names_prefix =");#NormalTok(" ");#StringTok("\"age_\"");],
[#NormalTok("  ) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("age2 =");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(age2)");],
[#NormalTok("  )");],));
]
=== Checking assumptions (normal ANOVA)
<checking-assumptions-normal-anova-1>
Like last time, let's examine our assumptions using a normal repeated-measures ANOVA. We can see that our sphericity assumption is violated (#emph[p] \< .001), and very severely so; recall that the W statistic in Mauchly's test is a deviation from 1, so our test statistic of #emph[W] = .047 is very low! This might be one instance where we would legitimately consider running a Friedman ANOVA, if we weren't keen on applying such a strong Greenhouse-Geisser correction to our ANOVA.

#block[
#Skylighting(([#NormalTok("autism ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("anova_test");#NormalTok("(");#AttributeTok("dv =");#NormalTok(" vsae, ");#AttributeTok("within =");#NormalTok(" age2, ");#AttributeTok("wid =");#NormalTok(" childid)");],));
#block[
#Skylighting(([#NormalTok("ANOVA Table (type III tests)");],
[],
[#NormalTok("$ANOVA");],
[#NormalTok("  Effect DFn DFd      F        p p<.05   ges");],
[#NormalTok("1   age2   3 186 48.401 3.62e-23     * 0.286");],
[],
[#NormalTok("$`Mauchly's Test for Sphericity`");],
[#NormalTok("  Effect     W        p p<.05");],
[#NormalTok("1   age2 0.047 4.88e-38     *");],
[],
[#NormalTok("$`Sphericity Corrections`");],
[#NormalTok("  Effect   GGe     DF[GG]    p[GG] p[GG]<.05   HFe      DF[HF]    p[HF]");],
[#NormalTok("1   age2 0.434 1.3, 80.71 2.02e-11         * 0.439 1.32, 81.73 1.55e-11");],
[#NormalTok("  p[HF]<.05");],
[#NormalTok("1         *");],));
]
]
=== Running a Friedman ANOVA
<running-a-friedman-anova>
Friedman ANOVAs are available in R with the #NormalTok("friedman.test()"); function. This function requires long data, and by and large even uses the same formula notation that we are used to. The only difference is that because this is repeated measures data, we must tweak the formula slightly to account for this. The formula needs to take #NormalTok("outcome ~ predictor | id"); notation, where #NormalTok("id"); needs to point to a column in the dataset that simply indicates each participant's unique ID. Otherwise, the formula is much as you would expect:

#block[
#Skylighting(([#FunctionTok("friedman.test");#NormalTok("(vsae ");#SpecialCharTok("~");#NormalTok(" age2 ");#SpecialCharTok("|");#NormalTok(" childid, ");#AttributeTok("data =");#NormalTok(" autism)");],));
#block[
#Skylighting(([],
[#NormalTok("    Friedman rank sum test");],
[],
[#NormalTok("data:  vsae and age2 and childid");],
[#NormalTok("Friedman chi-squared = 133.51, df = 3, p-value < 2.2e-16");],));
]
]
Also like the Kruskal-Wallis ANOVA, R will report a chi-square as the test statistic. This is for the same reason as before; the actual test statistic #emph[Q] approximates a chi-square distribution with large enough samples (e.g.~n \> 15). We can see that our omnibus result is significant ($chi^2$\(3) = 133.51, #emph[p] \< .001).

Although Jamovi does not give an effect size for a Friedman ANOVA, there actually is one called Kendall's #emph[W]. The #NormalTok("effectsize"); package provides a function called - you guessed it - #NormalTok("kendalls_w()"); to calculate this. The notation is the same as #NormalTok("friedman.test()");.

#block[
#Skylighting(([#FunctionTok("kendalls_w");#NormalTok("(vsae ");#SpecialCharTok("~");#NormalTok(" age2 ");#SpecialCharTok("|");#NormalTok(" childid, ");#AttributeTok("data =");#NormalTok(" autism)");],));
#block[
#Skylighting(([#NormalTok("Warning: 9 block(s) contain ties.");],));
]
#block[
#Skylighting(([#NormalTok("Kendall's W |       95% CI");],
[#NormalTok("--------------------------");],
[#NormalTok("0.71        | [0.59, 1.00]");],
[],
[#NormalTok("- One-sided CIs: upper bound fixed at [1.00].");],));
]
]
Of course, we still need to do post-hoc pairwise comparisons. The post-hocs that Jamovi provides are called Durbin-Conover pairwise comparisons, which are simply called Durbin tests elsewhere. The #NormalTok("PMCMRplus"); package we mentioned earlier provides a function called #NormalTok("durbinAllPairsTest()"); to conduct these posthocs. Note that although the function can be run without assigning the output to a new object, this will only give #emph[p]-values; to get the proper output, we will want to assign the function's output to a variable and then run #NormalTok("summary()"); on this.

This function will also allow you to use #emph[p]-value adjustment methods. Holm adjusted #emph[p] values are the default, which we will run with.

#block[
#Skylighting(([#NormalTok("autism_posthoc ");#OtherTok("<-");#NormalTok(" PMCMRplus");#SpecialCharTok("::");#FunctionTok("durbinAllPairsTest");#NormalTok("(");#AttributeTok("y =");#NormalTok(" autism");#SpecialCharTok("$");#NormalTok("vsae, ");#AttributeTok("groups =");#NormalTok(" autism");#SpecialCharTok("$");#NormalTok("age2, ");#AttributeTok("blocks =");#NormalTok(" autism");#SpecialCharTok("$");#NormalTok("childid)");],
[#FunctionTok("summary");#NormalTok("(autism_posthoc)");],));
#block[
#Skylighting(([],
[#NormalTok("    Pairwise comparisons using Durbin's all-pairs test for a two-way balanced incomplete block design");],));
]
#block[
#Skylighting(([#NormalTok("data: autism$vsae, autism$age2 and autism$childid");],));
]
#block[
#Skylighting(([#NormalTok("P value adjustment method: holm");],));
]
#block[
#Skylighting(([#NormalTok("H0");],));
]
#block[
#Skylighting(([#NormalTok("           t value   Pr(>|t|)    ");],
[#NormalTok("1 - 0 == 0   7.317 2.2075e-11 ***");],
[#NormalTok("3 - 0 == 0  14.189 < 2.22e-16 ***");],
[#NormalTok("7 - 0 == 0  19.979 < 2.22e-16 ***");],
[#NormalTok("3 - 1 == 0   6.872 1.8542e-10 ***");],
[#NormalTok("7 - 1 == 0  12.662 < 2.22e-16 ***");],
[#NormalTok("7 - 3 == 0   5.790 2.9470e-08 ***");],));
]
#block[
#Skylighting(([#NormalTok("---");],));
]
#block[
#Skylighting(([#NormalTok("Signif. codes: 0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
]
The left column of this output is denoting a specific hypothesis being tested. For example, "1 - 0 == 0" means that it is testing whether the difference between age2 = 1 and age2 = 0 is equal to 0. The corresponding columns to the right give the test statistic and the #emph[p]-value.

Based on our results, we can see that all comparisons are significant (#emph[p] \< .001). To interpret this, the most useful way would be to draw a plot and go back to the main descriptives, to infer that there is a significant increase or decrease in expressive language with age.

#show: appendices.with("Appendices", hide-parent: true)
#heading(level: 1, numbering: none)[Appendices]
#heading(level: 1, numbering: none)[Appendix]
<appendix>
#heading(level: 1, numbering: none)[R colour palettes]
<colours>
#box(image("appendix_files/figure-typst/unnamed-chunk-3-1.svg"))

#heading(level: 1, numbering: none)[The #NormalTok("broom()"); package]
<broom>
The #NormalTok("broom()"); package provides a couple of helper functions for tidying up output from numerous R functions for running tests. This can be useful in a couple of instances, particularly for either a) accessing certain aspects of models that are not immediately accessible or b) simply for neater manipulation for multiple models.

While #NormalTok("broom"); is a part of the tidyverse, it is not one of the tidyverse's default packages. Therefore, to use the package you need to manually call it:

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(broom)");],));
]
For the examples on this page, we will use datasets from the #NormalTok("datarium"); package (which we have seen before), just because it provides a nice set of datasets for demonstrating how these functions work. So let's go ahead and load that too:

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(datarium)");],));
]
The main functions in #NormalTok("broom"); are generic functions with what R calls several #emph[methods] - i.e.~ways that the function handles different types of data or objects. Every method comes with a different set of arguments that can change the output, depending on what object the function is run on. For example, if you use #NormalTok("tidy()"); on an #NormalTok("lm"); object, you get different optional arguments than for an #NormalTok("aov()"); object, and so on. The next page gives examples using the #NormalTok("datarium"); datasets.

#heading(level: 2, numbering: none)[The #NormalTok("tidy()"); function]
<broom-tidy>
You may have noticed that many of the outputs from common R functions, like #NormalTok("lm()"); and #NormalTok("aov()");, print their results in a certain format - namely, it essentially prints as text. The #NormalTok("tidy()"); function will simply turn the core output into a data frame. This is useful when you are running multiple models at once, or if for some reason you want to work with the values in model outputs directly. This function will work with just about every standard test function you get in R.

Here an example with the #NormalTok("marketing"); dataset, which contains continuous variables. Let's fit a multiple regression using #NormalTok("lm()");, and call #NormalTok("summary()"); on the results:

#block[
#Skylighting(([#FunctionTok("data");#NormalTok("(marketing)");],
[],
[#NormalTok("marketing_lm ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(sales ");#SpecialCharTok("~");#NormalTok(" youtube ");#SpecialCharTok("+");#NormalTok(" facebook ");#SpecialCharTok("+");#NormalTok(" newspaper, ");#AttributeTok("data =");#NormalTok(" marketing)");],
[#FunctionTok("summary");#NormalTok("(marketing_lm)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = sales ~ youtube + facebook + newspaper, data = marketing)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("     Min       1Q   Median       3Q      Max ");],
[#NormalTok("-10.5932  -1.0690   0.2902   1.4272   3.3951 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("             Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept)  3.526667   0.374290   9.422   <2e-16 ***");],
[#NormalTok("youtube      0.045765   0.001395  32.809   <2e-16 ***");],
[#NormalTok("facebook     0.188530   0.008611  21.893   <2e-16 ***");],
[#NormalTok("newspaper   -0.001037   0.005871  -0.177     0.86    ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 2.023 on 196 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.8972,    Adjusted R-squared:  0.8956 ");],
[#NormalTok("F-statistic: 570.3 on 3 and 196 DF,  p-value: < 2.2e-16");],));
]
]
#NormalTok("tidy()"); works directly on #emph[model] objects, not raw data, so we use the #NormalTok("tidy()"); function on our regression model. As you can see, the data is now in data frame format:

#block[
#Skylighting(([#FunctionTok("tidy");#NormalTok("(marketing_lm)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 4 × 5");],
[#NormalTok("  term        estimate std.error statistic  p.value");],
[#NormalTok("  <chr>          <dbl>     <dbl>     <dbl>    <dbl>");],
[#NormalTok("1 (Intercept)  3.53      0.374       9.42  1.27e-17");],
[#NormalTok("2 youtube      0.0458    0.00139    32.8   1.51e-81");],
[#NormalTok("3 facebook     0.189     0.00861    21.9   1.51e-54");],
[#NormalTok("4 newspaper   -0.00104   0.00587    -0.177 8.60e- 1");],));
]
]
For #NormalTok("lm()"); objects, you can return a confidence interval on the regression coefficients:

#block[
#Skylighting(([#FunctionTok("tidy");#NormalTok("(marketing_lm, ");#AttributeTok("conf.int =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("conf.level =");#NormalTok(" ");#FloatTok("0.95");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 4 × 7");],
[#NormalTok("  term        estimate std.error statistic  p.value conf.low conf.high");],
[#NormalTok("  <chr>          <dbl>     <dbl>     <dbl>    <dbl>    <dbl>     <dbl>");],
[#NormalTok("1 (Intercept)  3.53      0.374       9.42  1.27e-17   2.79      4.26  ");],
[#NormalTok("2 youtube      0.0458    0.00139    32.8   1.51e-81   0.0430    0.0485");],
[#NormalTok("3 facebook     0.189     0.00861    21.9   1.51e-54   0.172     0.206 ");],
[#NormalTok("4 newspaper   -0.00104   0.00587    -0.177 8.60e- 1  -0.0126    0.0105");],));
]
]
#heading(level: 3, numbering: none)[Correlations]
<correlations-1>
For a correlation:

#block[
#Skylighting(([#NormalTok("marketing_cor ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cor.test");#NormalTok("(marketing");#SpecialCharTok("$");#NormalTok("youtube, marketing");#SpecialCharTok("$");#NormalTok("facebook)");],
[#NormalTok("marketing_cor");],));
#block[
#Skylighting(([],
[#NormalTok("    Pearson's product-moment correlation");],
[],
[#NormalTok("data:  marketing$youtube and marketing$facebook");],
[#NormalTok("t = 0.77239, df = 198, p-value = 0.4408");],
[#NormalTok("alternative hypothesis: true correlation is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" -0.08457548  0.19208899");],
[#NormalTok("sample estimates:");],
[#NormalTok("       cor ");],
[#NormalTok("0.05480866 ");],));
]
]
#block[
#Skylighting(([#FunctionTok("tidy");#NormalTok("(marketing_cor)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 8");],
[#NormalTok("  estimate statistic p.value parameter conf.low conf.high method     alternative");],
[#NormalTok("     <dbl>     <dbl>   <dbl>     <int>    <dbl>     <dbl> <chr>      <chr>      ");],
[#NormalTok("1   0.0548     0.772   0.441       198  -0.0846     0.192 Pearson's… two.sided  ");],));
]
]
#heading(level: 3, numbering: none)[Chi-squares]
<chi-squares-1>
A chi-square test object:

#block[
#Skylighting(([#FunctionTok("data");#NormalTok("(");#StringTok("\"properties\"");#NormalTok(")");],
[],
[#NormalTok("properties_table ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("table");#NormalTok("(properties");#SpecialCharTok("$");#NormalTok("property_type, properties");#SpecialCharTok("$");#NormalTok("buyer_type)");],
[#NormalTok("properties_chisq ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("chisq.test");#NormalTok("(properties_table, ");#AttributeTok("correct =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],
[#NormalTok("properties_chisq");],));
#block[
#Skylighting(([],
[#NormalTok("    Pearson's Chi-squared test");],
[],
[#NormalTok("data:  properties_table");],
[#NormalTok("X-squared = 82.504, df = 9, p-value = 5.134e-14");],));
]
]
#block[
#Skylighting(([#FunctionTok("tidy");#NormalTok("(properties_chisq)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 4");],
[#NormalTok("  statistic  p.value parameter method                    ");],
[#NormalTok("      <dbl>    <dbl>     <int> <chr>                     ");],
[#NormalTok("1      82.5 5.13e-14         9 Pearson's Chi-squared test");],));
]
]
#heading(level: 3, numbering: none)[t-tests]
<t-tests-1>
For a t-test object (applies to all t-tests):

#block[
#Skylighting(([#FunctionTok("data");#NormalTok("(");#StringTok("\"genderweight\"");#NormalTok(")");],
[],
[#NormalTok("weight_t ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("t.test");#NormalTok("(weight ");#SpecialCharTok("~");#NormalTok(" group, ");#AttributeTok("data =");#NormalTok(" genderweight)");],
[#NormalTok("weight_t");],));
#block[
#Skylighting(([],
[#NormalTok("    Welch Two Sample t-test");],
[],
[#NormalTok("data:  weight by group");],
[#NormalTok("t = -20.791, df = 26.872, p-value < 2.2e-16");],
[#NormalTok("alternative hypothesis: true difference in means between group F and group M is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" -24.53135 -20.12353");],
[#NormalTok("sample estimates:");],
[#NormalTok("mean in group F mean in group M ");],
[#NormalTok("       63.49867        85.82612 ");],));
]
]
#block[
#Skylighting(([#FunctionTok("tidy");#NormalTok("(weight_t)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 10");],
[#NormalTok("  estimate estimate1 estimate2 statistic  p.value parameter conf.low conf.high");],
[#NormalTok("     <dbl>     <dbl>     <dbl>     <dbl>    <dbl>     <dbl>    <dbl>     <dbl>");],
[#NormalTok("1    -22.3      63.5      85.8     -20.8 4.30e-18      26.9    -24.5     -20.1");],
[#NormalTok("# ℹ 2 more variables: method <chr>, alternative <chr>");],));
]
]
#heading(level: 3, numbering: none)[ANOVA objects]
<anova-objects>
For a regular #NormalTok("aov()"); object, you can optionally ask for the intercept term using #NormalTok("intercept = TRUE");:

#block[
#Skylighting(([#FunctionTok("data");#NormalTok("(");#StringTok("\"stress\"");#NormalTok(")");],
[],
[#NormalTok("stress_aov ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov");#NormalTok("(score ");#SpecialCharTok("~");#NormalTok(" treatment ");#SpecialCharTok("*");#NormalTok(" exercise, ");#AttributeTok("data =");#NormalTok(" stress)");],
[#FunctionTok("summary");#NormalTok("(stress_aov)");],));
#block[
#Skylighting(([#NormalTok("                   Df Sum Sq Mean Sq F value   Pr(>F)    ");],
[#NormalTok("treatment           1  351.4   351.4  12.295 0.000923 ***");],
[#NormalTok("exercise            2 1776.3   888.1  31.076 1.04e-09 ***");],
[#NormalTok("treatment:exercise  2  217.3   108.7   3.802 0.028522 *  ");],
[#NormalTok("Residuals          54 1543.3    28.6                     ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
]
#block[
#Skylighting(([#FunctionTok("tidy");#NormalTok("(stress_aov)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 4 × 6");],
[#NormalTok("  term                  df sumsq meansq statistic  p.value");],
[#NormalTok("  <chr>              <dbl> <dbl>  <dbl>     <dbl>    <dbl>");],
[#NormalTok("1 treatment              1  351.  351.      12.3   9.23e-4");],
[#NormalTok("2 exercise               2 1776.  888.      31.1   1.04e-9");],
[#NormalTok("3 treatment:exercise     2  217.  109.       3.80  2.85e-2");],
[#NormalTok("4 Residuals             54 1543.   28.6     NA    NA      ");],));
]
]
Objects fitted by the #NormalTok("Anova"); package also work, #emph[but] repeated measures designs do not work. It's best to stick to #NormalTok("rstatix"); if you want a repeated measures ANOVA in dataframe format.

#NormalTok("TukeyHSD()"); can also be used:

#block[
#Skylighting(([#FunctionTok("TukeyHSD");#NormalTok("(stress_aov) ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("tidy");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 19 × 7");],
[#NormalTok("   term              contrast null.value estimate conf.low conf.high adj.p.value");],
[#NormalTok("   <chr>             <chr>         <dbl>    <dbl>    <dbl>     <dbl>       <dbl>");],
[#NormalTok(" 1 treatment         no-yes            0    4.84      2.07     7.61     9.23 e-4");],
[#NormalTok(" 2 exercise          moderat…          0   -0.610    -4.68     3.46     9.31 e-1");],
[#NormalTok(" 3 exercise          high-low          0  -11.8     -15.9     -7.76     1.23 e-8");],
[#NormalTok(" 4 exercise          high-mo…          0  -11.2     -15.3     -7.15     4.72 e-8");],
[#NormalTok(" 5 treatment:exerci… no:low-…          0    1.73     -5.33     8.79     9.78 e-1");],
[#NormalTok(" 6 treatment:exerci… yes:mod…          0   -1.04     -8.10     6.02     9.98 e-1");],
[#NormalTok(" 7 treatment:exerci… no:mode…          0    1.55     -5.51     8.61     9.87 e-1");],
[#NormalTok(" 8 treatment:exerci… yes:hig…          0  -16.1     -23.1     -9.01     1.72 e-7");],
[#NormalTok(" 9 treatment:exerci… no:high…          0   -5.87    -12.9      1.19     1.56 e-1");],
[#NormalTok("10 treatment:exerci… yes:mod…          0   -2.77     -9.83     4.29     8.54 e-1");],
[#NormalTok("11 treatment:exerci… no:mode…          0   -0.180    -7.24     6.88     1.000e+0");],
[#NormalTok("12 treatment:exerci… yes:hig…          0  -17.8     -24.9    -10.7      1.16 e-8");],
[#NormalTok("13 treatment:exerci… no:high…          0   -7.60    -14.7     -0.536    2.80 e-2");],
[#NormalTok("14 treatment:exerci… no:mode…          0    2.59     -4.47     9.65     8.86 e-1");],
[#NormalTok("15 treatment:exerci… yes:hig…          0  -15.0     -22.1     -7.97     8.64 e-7");],
[#NormalTok("16 treatment:exerci… no:high…          0   -4.83    -11.9      2.23     3.45 e-1");],
[#NormalTok("17 treatment:exerci… yes:hig…          0  -17.6     -24.7    -10.6      1.53 e-8");],
[#NormalTok("18 treatment:exerci… no:high…          0   -7.42    -14.5     -0.356    3.42 e-2");],
[#NormalTok("19 treatment:exerci… no:high…          0   10.2       3.14    17.3      1.09 e-3");],));
]
]
#NormalTok("emmeans"); objects can also be tidied, e.g.~for simple effects tests:

#block[
#Skylighting(([#CommentTok("# Simple effects of exercise for every treatment");],
[],
[#FunctionTok("emmeans");#NormalTok("(stress_aov, ");#SpecialCharTok("~");#NormalTok(" exercise, ");#AttributeTok("by =");#NormalTok(" ");#StringTok("\"treatment\"");#NormalTok(") ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("pairs");#NormalTok("() ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("tidy");#NormalTok("()");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 9");],
[#NormalTok("  treatment term     contrast      null.value estimate std.error    df statistic");],
[#NormalTok("  <chr>     <chr>    <chr>              <dbl>    <dbl>     <dbl> <dbl>     <dbl>");],
[#NormalTok("1 yes       exercise low - modera…          0    1.04       2.39    54    0.435 ");],
[#NormalTok("2 yes       exercise low - high             0   16.1        2.39    54    6.72  ");],
[#NormalTok("3 yes       exercise moderate - h…          0   15.0        2.39    54    6.29  ");],
[#NormalTok("4 no        exercise low - modera…          0    0.180      2.39    54    0.0753");],
[#NormalTok("5 no        exercise low - high             0    7.60       2.39    54    3.18  ");],
[#NormalTok("6 no        exercise moderate - h…          0    7.42       2.39    54    3.10  ");],
[#NormalTok("# ℹ 1 more variable: adj.p.value <dbl>");],));
]
]
#heading(level: 2, numbering: none)[The #NormalTok("glance()"); function]
<broom-glance>
The #NormalTok("glance()"); function will generate model fit summaries from models. It works primarily with #NormalTok("lm()"); and other models, and returns several indices of model fit (depending on the original object).

For #NormalTok("lm()"); objects, importantly, it returns $R^2$ and adjusted $R^2$. IT also returns estimates for the AIC and BIC, as well as some other fit statistics.

#block[
#Skylighting(([#FunctionTok("glance");#NormalTok("(marketing_lm)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 12");],
[#NormalTok("  r.squared adj.r.squared sigma statistic  p.value    df logLik   AIC   BIC");],
[#NormalTok("      <dbl>         <dbl> <dbl>     <dbl>    <dbl> <dbl>  <dbl> <dbl> <dbl>");],
[#NormalTok("1     0.897         0.896  2.02      570. 1.58e-96     3  -423.  855.  872.");],
[#NormalTok("# ℹ 3 more variables: deviance <dbl>, df.residual <int>, nobs <int>");],));
]
]
#NormalTok("glance()"); also works for #NormalTok("aov()"); objects, but is perhaps less useful.

#block[
#Skylighting(([#FunctionTok("glance");#NormalTok("(stress_aov)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 6");],
[#NormalTok("  logLik   AIC   BIC deviance  nobs r.squared");],
[#NormalTok("   <dbl> <dbl> <dbl>    <dbl> <int>     <dbl>");],
[#NormalTok("1  -183.  379.  394.    1543.    60     0.603");],));
]
]
#heading(level: 2, numbering: none)[The #NormalTok("augment()"); function]
<broom-augment>
The #NormalTok("augment()"); function is another useful function in #NormalTok("broom");. The important distinction between this function and the two other ones from #NormalTok("broom"); is that #NormalTok("augment()"); returns information on each #emph[observation] or datapoint, whereas #NormalTok("glance()"); returns additional information on the whole model.

#heading(level: 3, numbering: none)[Chi-square tests]
<chi-square-tests>
Using #NormalTok("augment()"); on a chi-square object will print out a dataframe containing both the expected and the observed proportions for each cell.

#block[
#Skylighting(([#FunctionTok("augment");#NormalTok("(properties_chisq)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 16 × 9");],
[#NormalTok("   Var1  Var2  .observed  .prop .row.prop .col.prop .expected  .resid .std.resid");],
[#NormalTok("   <fct> <fct>     <int>  <dbl>     <dbl>     <dbl>     <dbl>   <dbl>      <dbl>");],
[#NormalTok(" 1 flat  sing…        40 0.120     0.417     0.588      19.6   4.61       6.12  ");],
[#NormalTok(" 2 bung… sing…         4 0.0120    0.105     0.0588      7.76 -1.35      -1.61  ");],
[#NormalTok(" 3 deta… sing…         8 0.0240    0.0870    0.118      18.8  -2.49      -3.28  ");],
[#NormalTok(" 4 terr… sing…        16 0.0480    0.150     0.235      21.8  -1.25      -1.70  ");],
[#NormalTok(" 5 flat  sing…        30 0.0901    0.312     0.526      16.4   3.35       4.36  ");],
[#NormalTok(" 6 bung… sing…         4 0.0120    0.105     0.0702      6.50 -0.982     -1.15  ");],
[#NormalTok(" 7 deta… sing…        16 0.0480    0.174     0.281      15.7   0.0636     0.0821");],
[#NormalTok(" 8 terr… sing…         7 0.0210    0.0654    0.123      18.3  -2.64      -3.53  ");],
[#NormalTok(" 9 flat  marr…        16 0.0480    0.167     0.158      29.1  -2.43      -3.45  ");],
[#NormalTok("10 bung… marr…        14 0.0420    0.368     0.139      11.5   0.729      0.928 ");],
[#NormalTok("11 deta… marr…        26 0.0781    0.283     0.257      27.9  -0.360     -0.508 ");],
[#NormalTok("12 terr… marr…        45 0.135     0.421     0.446      32.5   2.20       3.20  ");],
[#NormalTok("13 flat  fami…        10 0.0300    0.104     0.0935     30.8  -3.75      -5.40  ");],
[#NormalTok("14 bung… fami…        16 0.0480    0.421     0.150      12.2   1.08       1.40  ");],
[#NormalTok("15 deta… fami…        42 0.126     0.457     0.393      29.6   2.29       3.26  ");],
[#NormalTok("16 terr… fami…        39 0.117     0.364     0.364      34.4   0.788      1.16  ");],));
]
]
#heading(level: 3, numbering: none)[Regressions]
<regressions>
#NormalTok("augment()"); is probably most useful for regression models. It will print out the following:

- #NormalTok(".fitted"); is the predicted score for each participant
- #NormalTok(".resid"); is the residual for each participant (i.e.~actual - fitted)
- #NormalTok(".cooksd"); is Cook's distance, which is useful for outlier detection in some contexts

#block[
#Skylighting(([#FunctionTok("augment");#NormalTok("(marketing_lm)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 200 × 10");],
[#NormalTok("   sales youtube facebook newspaper .fitted  .resid    .hat .sigma    .cooksd");],
[#NormalTok("   <dbl>   <dbl>    <dbl>     <dbl>   <dbl>   <dbl>   <dbl>  <dbl>      <dbl>");],
[#NormalTok(" 1 26.5    276.     45.4       83.0   24.6   1.89   0.0252    2.02 0.00580   ");],
[#NormalTok(" 2 12.5     53.4    47.2       54.1   14.8  -2.33   0.0194    2.02 0.00667   ");],
[#NormalTok(" 3 11.2     20.6    55.1       83.2   14.8  -3.61   0.0392    2.01 0.0338    ");],
[#NormalTok(" 4 22.2    182.     49.6       70.2   21.1   1.08   0.0166    2.03 0.00123   ");],
[#NormalTok(" 5 15.5    217.     13.0       70.1   15.8  -0.346  0.0235    2.03 0.000181  ");],
[#NormalTok(" 6  8.64    10.4    58.7       90     15.0  -6.33   0.0475    1.97 0.128     ");],
[#NormalTok(" 7 14.2     69      39.4       28.2   14.1   0.0843 0.0144    2.03 0.00000645");],
[#NormalTok(" 8 15.8    144.     23.5       13.9   14.5   1.29   0.00918   2.03 0.000955  ");],
[#NormalTok(" 9  5.76    10.3     2.52       1.2    4.47  1.29   0.0307    2.03 0.00331   ");],
[#NormalTok("10 12.7    240.      3.12      25.4   15.1  -2.34   0.0171    2.02 0.00595   ");],
[#NormalTok("# ℹ 190 more rows");],
[#NormalTok("# ℹ 1 more variable: .std.resid <dbl>");],));
]
]
#heading(level: 1, numbering: none)[Technical details of #NormalTok("anova()");]
<technical-details-of-anova>
#block[
#block[
#Skylighting(([#NormalTok("Rows: 811 Columns: 6");],
[#NormalTok("── Column specification ────────────────────────────────────────────────────────");],
[#NormalTok("Delimiter: \",\"");],
[#NormalTok("dbl (6): id, age, GoldMSI, DFS_Total, trait_anxiety, openness");],
[],
[#NormalTok("ℹ Use `spec()` to retrieve the full column specification for this data.");],
[#NormalTok("ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.");],));
]
]
Technical note: this test works not too unlike a regular ANOVA, except the F-test is being conducted on the residual sums of scores. From a mathematical point of view, we are essentially conducting an F-test on the change in the residual sum of squares with the following formula:

$ F \( d f_(d f_b - d f_a) \, d f_a \) = frac(M S_(c o m p), M S_a) = frac(\( S S_b - S S_a \) \/ \( p_a - p_b \), S S_a \/ d f_a) $

Consider two models, Model A and Model B. Imagine Model B is a nested version of Model A - i.e.~it it the same model as Model A but with less predictors. In our case, imagine Model B is #NormalTok("flow_block1"); (which only had one predictor) and Model A is #NormalTok("flow_block2"); (which had two). $p_a$ is the number of coefficients in Model A #emph[including] the intercept, and same with $p_b$.

The exact process is:

+ Calculate the difference between residual SS in the two models - this is the $\( S S_b - S S_a \)$ part of the formula above. This is just the difference in RSS between model 1 (model B) and 2 (model A), i.e.~10124.2 - 9982.9 = 141.3.

+ Calculate the difference in df $\( p_a - p_b \)$. In #NormalTok("flow_block1"); we have one predictor and one intercept, so we have 2 terms - this is $p_b$. In #NormalTok("flow_block2"); we have two predictors and one intercept, which makes $p_a = 3$. Therefore, $\( p_a - p_b \) = 3 - 2 = 1$.

+ Calculate a mean square ratio for the comparison, which is $M S_(c o m p)$. Essentially, we divide the result in step 1 (143.1) by the result in step 2 (1). This follows the same formula for mean squarews as we have seen before: $M S = frac(S S_(c o m p), d f_(c o m p))$, so $M S_(c o m p) = 141.3 / 1 = 141.3 .$ While this is identical to the sum of squares value in the table above, note that this is #emph[not] the same value.

+ Calculate a mean square ratio between RSS and df for the new model. This is the $S S_a \/ d f_a$ part of the equation. $d f_a$ is calculated as $n - p_a$, where n is the original sample size. So $d f_a = 811 - 3 = 808$. Note that the value for row 2 (which corresponds to Model A/#NormalTok("flow_block2");) under #NormalTok("Res.df"); is 808.

Note that $d f_b$ is the same; $n - p_b = 811 - 2 = 809$.

Same deal as above after that, except this time we use the values from the new model only, i.e.~residual SS for model A (#NormalTok("flow_block2");) and the residual df.

$M S_a = frac(S S_a, d f_a)$ $M S_a = 9982.9 / 808 = 12.33507$

#block[
#set enum(numbering: "1.", start: 5)
+ Calculate an F ratio between the MS of the comparison and the MS of the new model to calculate a value for F.
]

This is exactly the same formula as it would be for a regular ANOVA, just that now we are doing:

$ F = frac(M S_(c o m p), M S_a) $

$F = 141.3 / 12.33507 = 11.45514$

#block[
#set enum(numbering: "1.", start: 6)
+ Calculate a p-value for this F-statistic by comparing the p against an F distribution. The two dfs in the original formula are a) $d f_b - d f_a$ and b) $d f_a$. Which means:
]

- $d f_b$ is 809 - $d f_a$ is 808 = 1
- $d f_a$ is 808

So we end up with a test statistic of $F \( 1 \, 808 \) = 11.455$. We can use this to calculate a p-value by calculating the probability of getting a value of at least 11.455, on an F distribution with degrees of freedom parameters described above. We can visualise this below. Note that because the values for F are so infinitesimally small with these parameters and at this F-value, I've zoomed in the plot to visualise the highlighted area:

#Skylighting(([#FunctionTok("tibble");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("seq");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#DecValTok("15");#NormalTok(", ");#AttributeTok("by =");#NormalTok(" .");#DecValTok("5");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("y =");#NormalTok(" ");#FunctionTok("df");#NormalTok("(x, ");#AttributeTok("df1 =");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("df2 =");#NormalTok(" ");#DecValTok("809");#NormalTok(")");],
[#NormalTok(") ");#SpecialCharTok("%>%");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");],
[#NormalTok("    ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" x, ");#AttributeTok("y =");#NormalTok(" y)");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_line");#NormalTok("(");#AttributeTok("linewidth =");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_pubr");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_vline");#NormalTok("(");#AttributeTok("xintercept =");#NormalTok(" ");#FloatTok("11.455");#NormalTok(", ");#AttributeTok("linewidth =");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"royalblue\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("annotate");#NormalTok("(");#StringTok("\"text\"");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" ");#DecValTok("12");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#FloatTok("0.0024");#NormalTok(", ");#AttributeTok("label =");#NormalTok(" ");#StringTok("\"F = 11.455\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("stat_function");#NormalTok("(");#AttributeTok("fun =");#NormalTok(" df, ");#AttributeTok("args =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");#AttributeTok("df1 =");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("df2 =");#NormalTok(" ");#DecValTok("809");#NormalTok("), ");],
[#NormalTok("                ");#AttributeTok("geom =");#NormalTok(" ");#StringTok("\"area\"");#NormalTok(", ");#AttributeTok("xlim =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#FloatTok("11.455");#NormalTok(", ");#DecValTok("15");#NormalTok("),");],
[#NormalTok("                ");#AttributeTok("fill =");#NormalTok(" ");#StringTok("\"royalblue\"");#NormalTok(", ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.5");#NormalTok(") ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("scale_x_continuous");#NormalTok("(");#AttributeTok("expand =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok("), ");#AttributeTok("limits =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#ConstantTok("NA");#NormalTok(")) ");#SpecialCharTok("+");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("scale_y_continuous");#NormalTok("(");#AttributeTok("expand =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok("), ");#AttributeTok("limits =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#FloatTok("0.003");#NormalTok(")) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"F-value\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Density\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("Warning: Removed 20 rows containing missing values or values outside the scale range");],
[#NormalTok("(`geom_line()`).");],));
]
#box(image("appendix_files/figure-typst/unnamed-chunk-24-1.svg"))

R can manually calculate a p-value with the #NormalTok("pf()"); function. #NormalTok("pf()"); will calculate the probability of a value on the F distribution, given the two degrees of freedom parameters to characterise the distribution. #NormalTok("lower.tail = FALSE"); is used to indicate that we want to calculate the probability of getting something #emph[above] our critical F-value; #NormalTok("lower.tail = TRUE"); would calculuate the probability #emph[below] it.

#block[
#Skylighting(([#FunctionTok("pf");#NormalTok("(");#FloatTok("11.45514");#NormalTok(", ");#AttributeTok("df1 =");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("df2 =");#NormalTok(" ");#DecValTok("808");#NormalTok(", ");#AttributeTok("lower.tail =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 0.0007473355");],));
]
]
Note that our p-value isn't exactly the same as the value in the table - this is because we've used rounded values. The code below extracts the unrounded values and uses them in the calculations. As you can see we get the exact p-value in the table.

#block[
#Skylighting(([#NormalTok("x ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("anova");#NormalTok("(flow_block1, flow_block2)");],
[#NormalTok("x");],));
#block[
#Skylighting(([#NormalTok("Analysis of Variance Table");],
[],
[#NormalTok("Model 1: DFS_Total ~ GoldMSI");],
[#NormalTok("Model 2: DFS_Total ~ GoldMSI + openness");],
[#NormalTok("  Res.Df     RSS Df Sum of Sq      F    Pr(>F)    ");],
[#NormalTok("1    809 10124.2                                  ");],
[#NormalTok("2    808  9982.9  1     141.3 11.437 0.0007547 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
#Skylighting(([#CommentTok("# Using the output from anova() to manually calculate p-value");],
[#NormalTok("SSb ");#OtherTok("<-");#NormalTok(" x");#SpecialCharTok("$");#NormalTok("RSS[");#DecValTok("1");#NormalTok("]");],
[#NormalTok("SSa ");#OtherTok("<-");#NormalTok(" x");#SpecialCharTok("$");#NormalTok("RSS[");#DecValTok("2");#NormalTok("]");],
[#NormalTok("pa ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("length");#NormalTok("(");#FunctionTok("coef");#NormalTok("(flow_block2))");],
[#NormalTok("pb ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("length");#NormalTok("(");#FunctionTok("coef");#NormalTok("(flow_block1))");],
[#NormalTok("dfa ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("nrow");#NormalTok("(w10_flow) ");#SpecialCharTok("-");#NormalTok(" pa");],
[#NormalTok("dfb ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("nrow");#NormalTok("(w10_flow) ");#SpecialCharTok("-");#NormalTok(" pb");],
[],
[#NormalTok("f_val ");#OtherTok("<-");#NormalTok(" ((SSb");#SpecialCharTok("-");#NormalTok("SSa)");#SpecialCharTok("/");#NormalTok("(pa");#SpecialCharTok("-");#NormalTok("pb))");#SpecialCharTok("/");#NormalTok("(SSa");#SpecialCharTok("/");#NormalTok("dfa)");],
[],
[#FunctionTok("pf");#NormalTok("(f_val, ");#AttributeTok("df1 =");#NormalTok(" dfb");#SpecialCharTok("-");#NormalTok("dfa, ");#AttributeTok("df2 =");#NormalTok(" dfa, ");#AttributeTok("lower.tail =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 0.0007546911");],));
]
]



