; Included by Tauri before MUI pages are declared. Keep its installer logic intact.
!ifndef MIARINA_BRAND
!define MIARINA_BRAND
!define MUI_BGCOLOR "101820"
!define MUI_TEXTCOLOR "F5F7FA"
; Windows themed checkboxes ignore SetCtlColors. MUI's supported fallback
; disables that theme for finish-page controls so their labels stay readable.
!define MUI_FORCECLASSICCONTROLS
!define MUI_INSTFILESPAGE_COLORS "35C9BD 182530"
!define MUI_WELCOMEFINISHPAGE_BITMAP_NOSTRETCH
!define MUI_HEADERIMAGE_BITMAP_NOSTRETCH
!define MUI_HEADERIMAGE_RIGHT
!define MUI_WELCOMEPAGE_TITLE "$(MiarinaWelcomeTitle)"
!define MUI_WELCOMEPAGE_TEXT "$(MiarinaWelcomeText)"
!define MUI_FINISHPAGE_TITLE "$(MiarinaFinishTitle)"
!define MUI_FINISHPAGE_TEXT "$(MiarinaFinishText)"

LangString MiarinaWelcomeTitle 1036 "Bienvenue dans Miarina Media"
LangString MiarinaWelcomeTitle 1033 "Welcome to Miarina Media"
LangString MiarinaWelcomeText 1036 "Vos médias, à portée de main.$\r$\n$\r$\nTéléchargez, organisez et lisez vos vidéos et votre musique sur votre ordinateur.$\r$\n$\r$\nLes outils multimédias sont inclus.$\r$\n$\r$\nCliquez sur Suivant pour choisir le dossier d'installation."
LangString MiarinaWelcomeText 1033 "Your media. Your freedom.$\r$\n$\r$\nDownload, organize and play your videos and music on your computer.$\r$\n$\r$\nMedia tools are included.$\r$\n$\r$\nClick Next to choose where to install Miarina Media."
LangString MiarinaFinishTitle 1036 "Miarina Media est prêt"
LangString MiarinaFinishTitle 1033 "Miarina Media is ready"
LangString MiarinaFinishText 1036 "L'installation est terminée.$\r$\n$\r$\nOuvrez Miarina Media pour ajouter votre premier lien ou retrouver votre bibliothèque."
LangString MiarinaFinishText 1033 "Installation is complete.$\r$\n$\r$\nOpen Miarina Media to add your first link or browse your library."
!endif
