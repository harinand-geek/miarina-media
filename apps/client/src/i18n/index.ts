import { useCallback } from 'react';
import { useSettings } from '../stores/settings';

/**
 * Central FR/EN catalog (CDC UX-01). Strings come from the Windows v2
 * handoff (`L(fr, en)` in the prototype). Screens are migrated lot by lot:
 * docs/design-implementation-map.md lists which ones read this catalog.
 */
export type Lang = 'fr' | 'en';

const fr = {
  // Shell
  searchAll: 'Rechercher titres, vidéos, playlists…',
  offTitle: 'Vous êtes hors ligne.',
  offBody:
    'Les téléchargements en cours réessaient quelques fois puis s’arrêtent. La bibliothèque reste disponible.',
  minimize: 'Réduire la fenêtre',
  maximize: 'Agrandir la fenêtre',
  close: 'Fermer',
  preview: 'Aperçu navigateur : données de démonstration, pas celles de l’application.',
  navLabel: 'Navigation principale',
  spaces: 'Espace',
  spaceGet: 'Obtenir',
  spacePlay: 'Écouter',
  home: 'Accueil',
  downloads: 'Téléchargements',
  browser: 'Navigateur',
  torrents: 'Torrents',
  history: 'Historique',
  groupMusic: 'Musique',
  groupVideo: 'Vidéo',
  tracks: 'Titres',
  albums: 'Albums',
  artists: 'Artistes',
  folders: 'Dossiers',
  playlists: 'Playlists',
  favorites: 'Favoris',
  videos: 'Vidéos',
  nowPlaying: 'En lecture',
  nowPlayingLive: 'En lecture (lecture en cours)',
  settings: 'Réglages',
  updateAvailable: 'Mise à jour disponible',
  collapse: 'Réduire',
  collapseSidebar: 'Réduire la barre latérale',
  expandSidebar: 'Déployer la barre latérale',
  planned: 'PRÉVU',
  plannedHint: 'Prévu dans un prochain lot : pas encore disponible.',
  sumRunning: '{n} en cours',
  sumPaused: 'Tout en pause',
  sumIdle: 'Aucun téléchargement',
  sumQueue: '{n} en attente',
  sumProgress: 'Progression globale des téléchargements',

  // Player (shared)
  play: 'Lire',
  pause: 'Pause',
  previous: 'Précédent',
  next: 'Suivant',
  queue: 'File d’attente',
  expand: 'Agrandir',
  volume: 'Volume',
  mute: 'Couper le son',
  unmute: 'Rétablir le son',
  seek: 'Position de lecture',
  back10: 'Reculer de 10 s',
  forward10: 'Avancer de 10 s',
  shuffle: 'Aléatoire',
  repeatOff: 'Répétition désactivée',
  repeatAll: 'Répéter la file',
  repeatOne: 'Répéter le titre',
  nothingPlaying: 'Rien en lecture',
  nothingPlayingBody: 'Choisissez un titre ou une vidéo dans votre bibliothèque.',
  openLibrary: 'Ouvrir la bibliothèque',
  noArtist: 'Artiste inconnu',
  localFile: 'Fichier local',

  // Now playing
  sound: 'Son',
  upNext: 'À suivre',
  queueEmpty: 'La file est vide.',
  saveAsPlaylist: 'Enregistrer en playlist',
  clearQueue: 'Vider la file',
  queueCleared: 'File vidée. Aucun fichier supprimé.',
  removeFromQueue: 'Retirer de la file',
  moveUp: 'Monter',
  moveDown: 'Descendre',
  dragHint: 'Glisser pour réordonner, ou Alt + ↑/↓',
  eq: 'Égaliseur',
  eqPlanned:
    'L’égaliseur arrive avec le moteur de lecture natif (lot L05/L07). Le son actuel est restitué sans modification.',
  speed: 'Vitesse',
  sleep: 'Minuteur de sommeil',
  sleepOff: 'Désactivé',
  sleepEnd: 'Fin du titre',
  sleepMinutes: '{n} min',
  sleepNoteOff: 'La musique continue jusqu’à la fin de la file.',
  sleepNoteEnd: 'Arrêt à la fin de « {title} ». Miarina reste ouvert.',
  sleepNoteMinutes: 'Arrêt dans {n} min. Miarina reste ouvert.',
  timer: 'Minuteur',
  sleepStopped: 'Minuteur écoulé : lecture mise en pause.',

  // Video player
  back: 'Retour',
  fullscreen: 'Plein écran (F)',
  exitFullscreen: 'Quitter le plein écran (Échap)',
  fullscreenFailed: 'Impossible de changer le mode plein écran. Réessayez.',
  speedButton: 'Vitesse de lecture {rate}',
  tracksPlanned: 'Pistes et sous-titres : avec le moteur natif (WIN-05/06, après WIN-SPIKE)',
  pip: 'Image dans l’image',
  pipUnavailable: 'Image dans l’image (indisponible ici)',
  detailsPanel: 'Détails du fichier et file',
  file: 'Fichier',
  format: 'Format',
  resolution: 'Résolution',
  size: 'Taille',
  location: 'Emplacement',
  errUnsupported: 'Ce format ne peut pas être lu ici ({format}).',
  errRead: 'Le fichier n’a pas pu être lu. Réessayez de le charger.',
  errDecode: 'Le décodage audio ou vidéo s’est arrêté. Réessayez la lecture.',
  errOther: 'La lecture a été interrompue. Réessayez la lecture.',
  retry: 'Réessayer la lecture',
  openExternal: 'Ouvrir avec le lecteur du système',
  videoPreview: 'surface vidéo · aperçu',

  // Remove or delete (COM-10)
  removeOrDelete: 'Retirer ou supprimer…',
  removeOption: 'Retirer de la bibliothèque',
  removeOptionBody: 'Le fichier reste sur le disque. Il ne réapparaît pas au prochain scan.',
  deleteOption: 'Supprimer le fichier du disque',
  deleteOptionBody:
    'Le fichier est supprimé définitivement (il ne passe pas par la corbeille). Il est aussi retiré de la file de lecture.',
  removeConfirm: 'Retirer',
  deleteConfirm: 'Supprimer le fichier',
  removeDone: 'Retiré de la bibliothèque. Le fichier reste sur le disque.',
  deleteDone: 'Fichier supprimé du disque.',
  cancel: 'Annuler',

  // Language setting
  language: 'Langue',
  languageNote:
    'Français et anglais. Les écrans pas encore migrés vers le catalogue restent en anglais.',
} as const;

export type MessageKey = keyof typeof fr;

const en: Record<MessageKey, string> = {
  searchAll: 'Search tracks, videos, playlists…',
  offTitle: "You're offline.",
  offBody: 'Active downloads retry a few times, then stop. Your library stays available.',
  minimize: 'Minimize',
  maximize: 'Maximize',
  close: 'Close',
  preview: 'Browser preview: data comes from development fixtures, not from the desktop app.',
  navLabel: 'Main',
  spaces: 'Space',
  spaceGet: 'Get',
  spacePlay: 'Play',
  home: 'Home',
  downloads: 'Downloads',
  browser: 'Browser',
  torrents: 'Torrents',
  history: 'History',
  groupMusic: 'Music',
  groupVideo: 'Video',
  tracks: 'Tracks',
  albums: 'Albums',
  artists: 'Artists',
  folders: 'Folders',
  playlists: 'Playlists',
  favorites: 'Favorites',
  videos: 'Videos',
  nowPlaying: 'Now playing',
  nowPlayingLive: 'Now playing (playing)',
  settings: 'Settings',
  updateAvailable: 'Update available',
  collapse: 'Collapse',
  collapseSidebar: 'Collapse sidebar',
  expandSidebar: 'Expand sidebar',
  planned: 'PLANNED',
  plannedHint: 'Planned for a later lot: not available yet.',
  sumRunning: '{n} downloading',
  sumPaused: 'All paused',
  sumIdle: 'No downloads',
  sumQueue: '{n} waiting in queue',
  sumProgress: 'Overall download progress',

  play: 'Play',
  pause: 'Pause',
  previous: 'Previous',
  next: 'Next',
  queue: 'Queue',
  expand: 'Expand',
  volume: 'Volume',
  mute: 'Mute',
  unmute: 'Unmute',
  seek: 'Playback position',
  back10: 'Back 10 seconds',
  forward10: 'Forward 10 seconds',
  shuffle: 'Shuffle',
  repeatOff: 'Repeat off',
  repeatAll: 'Repeat queue',
  repeatOne: 'Repeat track',
  nothingPlaying: 'Nothing is playing',
  nothingPlayingBody: 'Choose a video or a song in your library.',
  openLibrary: 'Open library',
  noArtist: 'Unknown artist',
  localFile: 'Local file',

  sound: 'Sound',
  upNext: 'Up next',
  queueEmpty: 'The queue is empty.',
  saveAsPlaylist: 'Save as playlist',
  clearQueue: 'Clear queue',
  queueCleared: 'Queue cleared. No file deleted.',
  removeFromQueue: 'Remove from queue',
  moveUp: 'Move up',
  moveDown: 'Move down',
  dragHint: 'Drag to reorder, or Alt + ↑/↓',
  eq: 'Equalizer',
  eqPlanned:
    'The equalizer comes with the native playback engine (lots L05/L07). Sound currently plays unaltered.',
  speed: 'Speed',
  sleep: 'Sleep timer',
  sleepOff: 'Off',
  sleepEnd: 'End of track',
  sleepMinutes: '{n} min',
  sleepNoteOff: 'Music plays until the queue ends.',
  sleepNoteEnd: 'Stops after “{title}”. Miarina stays open.',
  sleepNoteMinutes: 'Stops in {n} min. Miarina stays open.',
  timer: 'Timer',
  sleepStopped: 'Sleep timer ended: playback paused.',

  back: 'Back',
  fullscreen: 'Fullscreen (F)',
  exitFullscreen: 'Exit fullscreen (Esc)',
  fullscreenFailed: 'Could not change fullscreen mode. Please try again.',
  speedButton: 'Playback speed {rate}',
  tracksPlanned: 'Tracks and subtitles: with the native engine (WIN-05/06, after WIN-SPIKE)',
  pip: 'Picture in picture',
  pipUnavailable: 'Picture in picture (not available here)',
  detailsPanel: 'File details and queue',
  file: 'File',
  format: 'Format',
  resolution: 'Resolution',
  size: 'Size',
  location: 'Location',
  errUnsupported: 'This format cannot be played here ({format}).',
  errRead: 'The media file could not be read. Try loading it again.',
  errDecode: 'Video or audio decoding stopped. Try resuming playback.',
  errOther: 'Playback was interrupted. Try resuming playback.',
  retry: 'Retry playback',
  openExternal: 'Open with system player',
  videoPreview: 'video surface · preview',

  removeOrDelete: 'Remove or delete…',
  removeOption: 'Remove from library',
  removeOptionBody: 'The file stays on disk. It will not reappear on the next scan.',
  deleteOption: 'Delete the file from disk',
  deleteOptionBody:
    'The file is deleted permanently (it does not go to the Recycle Bin). It is also removed from the play queue.',
  removeConfirm: 'Remove',
  deleteConfirm: 'Delete file',
  removeDone: 'Removed from library. The file stays on disk.',
  deleteDone: 'File deleted from disk.',
  cancel: 'Cancel',

  language: 'Language',
  languageNote: 'French and English. Screens not yet migrated to the catalog stay in English.',
};

const CATALOG: Record<Lang, Record<MessageKey, string>> = { fr, en };

export type Translate = (key: MessageKey, vars?: Record<string, string | number>) => string;

export function translate(lang: Lang, key: MessageKey, vars?: Record<string, string | number>) {
  const text = CATALOG[lang][key];
  if (!vars) return text;
  return text.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in vars ? String(vars[name]) : match,
  );
}

/** Translator bound to the current interface language. */
export function useT(): Translate {
  const lang = useSettings((s) => s.lang);
  return useCallback<Translate>((key, vars) => translate(lang, key, vars), [lang]);
}

/** Outside React (stores, toasts). */
export const t: Translate = (key, vars) => translate(useSettings.getState().lang, key, vars);
