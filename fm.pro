
; working with double images, since we are not interested in polarization

pro fm_process, path, $
  cor2sta=path_cor2_sta, bgcor2sta=path_cor2_sta_bg, $
  hi1sta=path_hi1_sta, bghi1sta=path_hi1_sta_bg, $
  cor2stb=path_cor2_stb, bgcor2stb=path_cor2_stb_bg, $
  hi1stb=path_hi1_stb, bghi1stb=path_hi1_stb_bg, $
  euvista=path_euvi_sta, euvistb=path_euvi_stb, $
  c2soho=path_c2_soho, bgc2soho=path_c2_soho_bg, $
  c3soho=path_c3_soho, bgc3soho=path_c3_soho_bg, $
  sparaminit=sparaminit

  ; prepare STEREO-A cor2 level-1 images
  if n_elements(path_cor2_sta) ne 0 then begin
    ; background
    secchi_prep, path_cor2_sta_bg, header_sta_bg, image_sta_bg, $
      /rotate_on, /precommcorrect_on, /rotinterp_on, /smask_on, /silent
    ; current
    secchi_prep, path_cor2_sta, header_sta, image_sta, $
      /rotate_on, /precommcorrect_on, /rotinterp_on, /smask_on, /silent
  endif

  ; prepare STEREO-B cor2 level-1 images
  if n_elements(path_cor2_stb) ne 0 then begin
    ; background
    secchi_prep, path_cor2_stb_bg, header_stb_bg, image_stb_bg, $
      /rotate_on, /precommcorrect_on, /rotinterp_on, /smask_on, /silent
    ; current
    secchi_prep, path_cor2_stb, header_stb, image_stb, $
      /rotate_on, /precommcorrect_on, /rotinterp_on, /smask_on, /silent
  endif

  ; prepare STEREO-A hi1 level-1 images
  if n_elements(path_hi1_sta) ne 0 then begin
    ; background
    secchi_prep, path_hi1_sta_bg, header_sta_bg, image_sta_bg
    ; current
    secchi_prep, path_hi1_sta, header_sta, image_sta
  endif

  ; prepare STEREO-B hi1 level-1 images
  if n_elements(path_hi1_stb) ne 0 then begin
    ; background
    secchi_prep, path_hi1_stb_bg, header_stb_bg, image_stb_bg
    ; current
    secchi_prep, path_hi1_stb, header_stb, image_stb
  endif

  ; prepare STEREO euvi images
  secchi_prep, path_euvi_sta, header_euvi_sta, image_euvi_sta, $
    /precommcorrect_on, /silent
  secchi_prep, path_euvi_stb, header_euvi_stb, image_euvi_stb, $
    /precommcorrect_on, /silent

  ; prepare SOHO c2 level-1 images
  if n_elements(path_c2_soho) ne 0 then begin
    ; background
    image_soho_bg = sccreadfits(path_c2_soho_bg, header_soho_bg, /lasco)
    ; fix lasco header
    fixed_header_soho_bg = header_soho_bg
    fm_fix_lasco_header, fixed_header_soho_bg
    ; current
    image_soho = sccreadfits(path_c2_soho, header_soho, /lasco)
    ; fix lasco header
    fixed_header_soho = header_soho
    fm_fix_lasco_header, fixed_header_soho
    ; read the header from the fits file for SOHO
    fits_header_soho = fitshead2struct(headfits(path_c2_soho), /wcs)
  endif

  ; prepare SOHO c3 level-1 images
  if n_elements(path_c3_soho) ne 0 then begin
    ; background
    image_soho_bg = sccreadfits(path_c3_soho_bg, header_soho_bg, /lasco)
    ; fix lasco header
    fixed_header_soho_bg = header_soho_bg
    fm_fix_lasco_header, fixed_header_soho_bg
    ; current
    image_soho = sccreadfits(path_c3_soho, header_soho, /lasco)
    ; fix lasco header
    fixed_header_soho = header_soho
    fm_fix_lasco_header, fixed_header_soho
    ; read the header from the fits file for SOHO
    fits_header_soho = fitshead2struct(headfits(path_c3_soho), /wcs)
  endif

  ; calculate mass images for the background timestamp
  mass_sta_bg = scc_calc_cme_mass(image_sta_bg, header_sta_bg, /all)
  mass_stb_bg = scc_calc_cme_mass(image_stb_bg, header_stb_bg, /all)
  mass_soho_bg = scc_calc_cme_mass(image_soho_bg, header_soho_bg, /all)

  ; calculate mass images for the current timestamp
  mass_sta = scc_calc_cme_mass(image_sta, header_sta, /all)
  mass_stb = scc_calc_cme_mass(image_stb, header_stb, /all)
  mass_soho  = scc_calc_cme_mass(image_soho, header_soho, /all)

  ; subtract and scale mass images
  scaled_mass_sta = select_bytscl(rebin(mass_sta-$
    mass_sta_bg, 512, 512), /modal)
  scaled_mass_stb = select_bytscl(rebin(mass_stb-$
    mass_stb_bg, 512, 512), /modal)
  scaled_mass_soho  = select_bytscl(rebin(mass_soho-$
    mass_soho_bg, 512, 512), /modal)

  ; rebin euvi images
  scaled_image_euvi_sta = alog10(rebin(image_euvi_sta, 512, 512) > 1)
  scaled_image_euvi_stb = alog10(rebin(image_euvi_stb, 512, 512) > 1)

  ; run gui for CME fitting
  rtsccguicloud, $
    scaled_mass_sta, scaled_mass_stb, $
    header_sta, header_stb, $
    imeuvia = scaled_image_euvi_sta, imeuvib = scaled_image_euvi_stb, $
    hdreuvia = header_euvi_sta, hdreuvib = header_euvi_stb, $
    imlasco = scaled_mass_soho, $
    hdrlasco = fixed_header_soho, $
    sgui = fit_params, swire = fit_frame, $
    maxheight = 40, $
    sparaminit = sparaminit

  ; close all the windows
  while !d.window ne -1 do wdelete

  ; save images and fittings
  ; enter the data directory
  cd, path
  ; save images
  savecombi, scaled_mass_sta, scaled_mass_stb, $
    header_sta, header_stb, fit_frame, sgui = fit_params, $
    imlasco = scaled_mass_soho, $
    hdrlasco = fits_header_soho

  ; write fit params into temporary file
  openw, 1, './.params'
  printf, 1, fit_params.lon, fit_params.lat, fit_params.rot, fit_params.han, $
             fit_params.hgt, fit_params.rat, $
             FORMAT='("{lon:", F6.1, ", lat:", F6.1, ", rot:", F6.1, ", han:", F6.1, ", hgt:", F6.1, ", rat:", F6.2, "}")'
  close, 1

  ; leave the data directory
  cd, '..'
end

; fix lasco headers, problem with case-sensivity and more
pro fm_fix_lasco_header, header
  header.ctype1 = strlowcase(header.ctype1)
  header.ctype2 = strlowcase(header.ctype2)
  if header.cunit1 eq '' then begin
    header.cunit1 = header.ctype1
  endif else begin
    header.cunit1 = strlowcase(header.cunit1)
  endelse
  if header.cunit2 eq '' then begin
    header.cunit2 = header.ctype2
  endif else begin
    header.cunit2 = strlowcase(header.cunit2)
  endelse
end

