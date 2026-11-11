import type { Translate } from '../../i18n';
import type { MediaRecord } from '../../services/types';
import { folderOf } from '../library/format';

/**
 * Secondary line under a title. Artist/album tags arrive with lot L06
 * (COM-07); until then the source site or the folder stands in.
 */
export function mediaByline(media: MediaRecord, t: Translate) {
  if (media.sourceHost) return media.sourceHost;
  const folder = folderOf(media.path).split(/[\\/]/).filter(Boolean).pop();
  return folder || t('localFile');
}
