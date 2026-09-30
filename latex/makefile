##
## macrodefinitions 
##
LATEXMK      = latexmk
SRC          = main
REMOVE       = *.tex~ *.aux *.glo *.gls *.cb *.dvi *.log *.toc *.lof *.bbl *.blg *.ilg *.cb? *.idx *.out

##
## rules
##
all : 
	$(LATEXMK) -pdf $(SRC).tex

clean :
	rm -fv $(REMOVE)
