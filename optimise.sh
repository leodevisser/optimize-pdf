#!/bin/bash
#Leo de Visser
#v05, 2023/03/24

echo "Optimise PDFs

Use:
./optimise.sh [Num] [File] [Threshold]
- Num: choice of optimisation settings
- File: filename
- Threshold: Imagemagick Threshold percentage for converting scans to black/white

Num:
- 1: 72p optimisation (yields bad results with scans)
- 2: 300p optimisation (usually most printer friendly but sometimes bulky)
- 3: converts each page to PNG, then reassembles them to PDF
- 4: converts PDF to PS and back (sometimes works for file size, often not)
- 5: converts each page to JPEG, then reassembles them to PDF

Threshold:
- Only used for cases 3 and 5
- Leave zero or blank to not use the black/white conversion
- Default percentage for good results is usually 85% (input example: ./optimise.sh 3 in.pdf 85)
"

# GhostScript bugs when handling file names with a space in them. I don't know why and I don't think
# I want to. The following code replaces all spaces " " in filenames to underscores "_" because I am a hack.
#https://stackoverflow.com/questions/2709458/how-to-replace-spaces-in-file-names-using-a-bash-script
for f in *\ *; do mv "$f" "${f// /_}"; done

# -sPAPERSIZE=a4 -dFIXEDMEDIA -dPDFFITPAGE
#https://stackoverflow.com/a/11205754

############## GS-pdfwrite 72dpi
if [ $1 == 1 ]; then
    filen=${2%.pdf}-A4-72p.pdf
    echo $filen
    pdfjam --a4paper $2 --outfile ${2%.pdf}-pdfjam.pdf			# Before optimisation, stretch/shrink page to A4 size
									# PDFJam will append -pdfjam to the A4-stretched page hence the final
									# part of this GhostScript command:
    gs -sOutputFile=$filen -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -dDownsampleColorImages=true -dDownsampleGrayImages=true -dDownsampleMonoImages=true -dColorImageResolution=72 -dGrayImageResolution=72 -dMonoImageResolution=72 -dColorImageDownsampleThreshold=1.0 -dGrayImageDownsampleThreshold=1.0 -dMonoImageDownsampleThreshold=1.0 ${2%.pdf}-pdfjam.pdf
    rm -f ${2%.pdf}-pdfjam.pdf
fi

#-sPAPERSIZE=a4 -dFIXEDMEDIA

############## GS-pdfwrite 300dpi
if [ $1 == 2 ]; then
    filen=${2%.pdf}-A4-300p.pdf
    echo $filen
    pdfjam --a4paper $2 --outfile ${2%.pdf}-pdfjam.pdf			# Before optimisation, stretch/shrink page to A4 size
									# PDFJam will append -pdfjam to the A4-stretched page hence the final
									# part of this GhostScript command:
    gs -sOutputFile=$filen -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -dDownsampleColorImages=true -dDownsampleGrayImages=true -dDownsampleMonoImages=true -dColorImageResolution=300 -dGrayImageResolution=300 -dMonoImageResolution=300 -dColorImageDownsampleThreshold=1.0 -dGrayImageDownsampleThreshold=1.0 -dMonoImageDownsampleThreshold=1.0 ${2%.pdf}-pdfjam.pdf
    rm -f ${2%.pdf}-pdfjam.pdf
fi


############### PNG opt
if [ $1 == 3 ]; then
    filen=${2%.pdf}
    if [ ! -d "$filen-temp" ];then
        mkdir $filen-temp                                               # create temp directory if it didn't exist already
    fi
    cp $2 $filen-temp/$2                                                # move given pdf to temp
    cd $filen-temp                                                      # work from temp
    printf -- '--- Bursting the PDF...\n'
    pdftk ${2%.pdf}-jam.pdf burst                                   # creates pdfs numbered pg_0000.pdf, pg_0001.pdf etc.
    printf -- '--- Converting each PDF to JPEG in batches of 20...\n'
    ls pg*.pdf |                                                    # list all these files, pipe them to next line
    while mapfile -t -n 20 ary && ((${#ary[@]})); do                # then create 'ary', which is an array of 20 of them
        count="${ary[0]}"                                           # $count is the number at which ImageMagick will start naming the files
        printf -- 'Next batch of pages, starting: %s\n' "${count:3:4}"
        convert -quality 100 -density 300 "${ary[@]}" -scene "${count:3:4}" page-%03d.png # CORE FUNCTION
    done
    rm -f pg*.pdf                                                   # remove the converted pages
    if [[ $3 -gt 0 && $3 -lt 100 ]]; then
        printf -- '--- Converting each PNG to the used threshold...\n'
        ls page-*.png |                                                 # list all the pages, pipe to next line
        while mapfile -t -n 20 ary && ((${#ary[@]})); do                # create 'ary', batches of 20 of each file
            count="${ary[0]}"
            printf -- 'Next batch of pages, starting: %s\n' "${count:5:3}"
            convert -quality 100 -density 300 -threshold "$3%" "${ary[@]}" -scene "${count:5:3}" image-%03d.png
        done
        rm -f page-*.png
        printf -- '--- Assembling PNGs into PDF\n'
    else echo "Skipping ImageMagick black/white conversion"
    fi
    convert -strip "*.png" "$filen-jam.pdf"                         # Use ImageMagick to put them together again
    # NB: https://stackoverflow.com/questions/62801827/why-doesnt-ghostscript-like-the-icc-profile-of-my-pdf
    # adding the -strip flag prevents errors!
    pdfjam --a4paper "$filen-jam.pdf" --outfile "$filen-A4-png.pdf"	# AFTER optimisation, stretch/shrink page to A4 size
    cp "$filen-A4-png.pdf" ..                                          # write result to parent folder
    cd ..                                                               # go back to original folder..
    rm -rf "$filen-temp"                                                # .. and delete temp directory
fi


############### PS opt
if [ $1 == 4 ]; then
    pdfjam --a4paper $2 --outfile ${2%.pdf}-pdfjam.pdf			# Before optimisation, stretch/shrink page to A4 size
    pdf2ps ${2%.pdf}-pdfjam.pdf ${2%.pdf}.ps
    ps2pdf ${2%.pdf}.ps ${2%.pdf}-A4-PS.pdf
    rm -f ${2%.pdf}.ps ${2%.pdf}-pdfjam.pdf
fi

############### JPEG opt
if [ $1 == 5 ]; then
    filen=${2%.pdf}
    if [ ! -d "$filen-temp" ];then
        mkdir $filen-temp                                               # create temp directory if it didn't exist already
    fi
    cp $2 $filen-temp/$2                                                # move given pdf to temp
    cd $filen-temp                                                      # work from temp
    pdfjam --a4paper $2 --outfile ${2%.pdf}-jam.pdf		            	# Before optimisation, stretch/shrink page to A4 size
    printf -- '--- Bursting the PDF...\n'
    pdftk ${2%.pdf}-jam.pdf burst                                   # creates pdfs numbered pg_0000.pdf, pg_0001.pdf etc.
    printf -- '--- Converting each PDF to JPEG in batches of 20...\n'
    ls pg*.pdf |                                                    # list all these files, pipe them to next line
    while mapfile -t -n 20 ary && ((${#ary[@]})); do                # then create 'ary', which is an array of 20 of them
        count="${ary[0]}"                                           # $count is the number at which ImageMagick will start naming the files
        printf -- 'Next batch of pages, starting: %s\n' "${count:3:4}"
        convert -quality 100 -density 300 "${ary[@]}" -scene "${count:3:4}" page-%03d.jpg # CORE FUNCTION
    done
    rm -f pg*.pdf                                                   # remove the converted pages
    if [[ $3 -gt 0 && $3 -lt 100 ]]; then
        printf -- '--- Converting each JPEG to the used threshold...\n'
        ls page-*.jpg |                                                 # list all the pages, pipe to next line
        while mapfile -t -n 20 ary && ((${#ary[@]})); do                # create 'ary', batches of 20 of each file
            count="${ary[0]}"
            printf -- 'Next batch of pages, starting: %s\n' "${count:5:3}"
            convert -quality 100 -density 300 -threshold "$3%" "${ary[@]}" -scene "${count:5:3}" image-%03d.jpg
        done
        rm -f page-*.jpg
        printf -- '--- Assembling JPGs into PDF\n'
    else echo "Skipping ImageMagick black/white conversion"
    fi
    convert -strip "*.jpg" "$filen-A4-jpeg.pdf"                         # Use ImageMagick to put them together again
    # NB: https://stackoverflow.com/questions/62801827/why-doesnt-ghostscript-like-the-icc-profile-of-my-pdf
    # adding the -strip flag prevents errors!
    cp "$filen-A4-jpeg.pdf" ..                                          # write result to parent folder
    cd ..                                                               # go back to original folder..
    rm -rf "$filen-temp"                                                # .. and delete temp directory
fi

### PostScript devices for converting to other formats:
#       pngmono Monochrome Portable Network Graphics (PNG)
#       pnggray 8-bit gray Portable Network Graphics (PNG)
#       png16   4-bit color Portable Network Graphics (PNG)
#       png256  8-bit color Portable Network Graphics (PNG)
#       png16m  24-bit color Portable Network Graphics (PNG)
#       psmono  PostScript (Level 1) monochrome image
#       psgray  PostScript (Level 1) 8-bit gray image
#       psrgb   PostScript (Level 2) 24-bit color image
