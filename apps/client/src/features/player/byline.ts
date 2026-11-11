import type { Translate } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { folderOf } from '../library/format';

/**
 * Secondary line under a title: artist · album from the tags, otherwise
 * the source site or the folder.
 */
export function mediaByline(media: MediaRecord, t: Translate) {
  const tagged = [media.artist, media.album].filter(Boolean).join(' · ');
  if (tagged) return tagged;
  if (media.sourceHost) return media.sourceHost;
  const folder = folderOf(media.path).split(/[\\/]/).filter(Boolean).pop();
  return folder || t('localFile');
}
