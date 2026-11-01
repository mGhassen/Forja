// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsCategoryProfileTitle => 'Profil et compte';

  @override
  String get settingsCategoryProfileSubtitle =>
      'Profil, synchronisation cloud, connexion';

  @override
  String get settingsCategoryAddonsTitle => 'Addons';

  @override
  String get settingsCategoryAddonsSubtitle =>
      'Lecture, IPTV, torrents, Stremio, debrid, LAN';

  @override
  String get settingsCategoryPacksTitle => 'Forja Packs';

  @override
  String get settingsCategoryPacksSubtitle =>
      'Installer et gérer les packs de plugins';

  @override
  String get settingsCategoryFeaturesTitle => 'Fonctionnalités';

  @override
  String get settingsCategoryFeaturesSubtitle =>
      'Onglets, ordre, menu par défaut';

  @override
  String get settingsCategoryDownloadsTitle => 'Téléchargements';

  @override
  String get settingsCategoryDownloadsSubtitle =>
      'Bibliothèque hors ligne et progression des téléchargements';

  @override
  String get settingsCategoryDataTitle => 'Données et sauvegarde';

  @override
  String get settingsCategoryDataSubtitle =>
      'Vider le cache, exporter, importer';

  @override
  String get settingsCategoryAboutTitle => 'À propos';

  @override
  String get settingsCategoryAboutSubtitle =>
      'Mises à jour, version, développeur';

  @override
  String get settingsLanguageGroupLabel => 'Langue';

  @override
  String get settingsLanguageRowTitle => 'Langue de l\'application';

  @override
  String get settingsLanguageRowSubtitle =>
      'Les menus et les écrans changent tout de suite. Les titres, les descriptions et les textes des packs se mettent complètement à jour après un redémarrage.';

  @override
  String get settingsLanguageSystemDefault => 'Langue du système';

  @override
  String get addonsHostDebridGroupLabel => 'Debrid';

  @override
  String get addonsHostDebridResolveTitle =>
      'Résoudre les magnets avec un debrid';

  @override
  String get addonsHostDebridResolveSubtitle =>
      'Utilise un plugin debrid installé via un pack pour les magnets torrent.';

  @override
  String get addonsHostDebridPluginTitle => 'Plugin de résolution des magnets';

  @override
  String get addonsHostDebridPluginSubtitle =>
      'Un seul plugin debrid peut être actif à la fois.';

  @override
  String get addonsHostPlayTogglesGroupLabel => 'Addons Forja';

  @override
  String get addonsHostPlayTogglesP2pAckedTitle =>
      'Vous connaissez le streaming P2P';

  @override
  String get addonsHostPlayTogglesP2pConfirmTitle =>
      'Confirmer que vous connaissez le streaming P2P';

  @override
  String get addonsHostPlayTogglesP2pAckedSubtitle =>
      'Torrent direct, Stremio et Nuvio peuvent être utilisés. Appuyer pour revoir.';

  @override
  String get addonsHostPlayTogglesP2pConfirmSubtitle =>
      'Requis une fois avant d\'activer Torrent direct, Stremio ou Nuvio.';

  @override
  String get addonsHostPlayTogglesTorrentTitle => 'Torrent direct';

  @override
  String get addonsHostPlayTogglesTorrentNativeSubtitle =>
      'Recherche dans les indexeurs Forja (Jackett / Prowlarr) ci-dessous.';

  @override
  String get addonsHostPlayTogglesTorrentAtvSubtitle =>
      'Rechercher des torrents ici. Lire un magnet nécessite un ordinateur associé (Paramètres → LAN).';

  @override
  String get addonsHostPlayTogglesStremioTitle => 'Stremio';

  @override
  String get addonsHostPlayTogglesStremioNativeSubtitle =>
      'Lire depuis les flux des addons Stremio installés.';

  @override
  String get addonsHostPlayTogglesNuvioTitle => 'Nuvio';

  @override
  String get addonsHostPlayTogglesNuvioNativeSubtitle =>
      'Lire depuis les addons scrapers Nuvio installés ci-dessous.';

  @override
  String get addonsHostPlayTogglesDirectHttpAtvSubtitle =>
      'Le HTTP direct est lu sur cette TV. Les magnets nécessitent un ordinateur associé (Paramètres → LAN).';

  @override
  String get addonsHostMdblistEnterKeyWarning => 'Veuillez saisir une clé API';

  @override
  String get addonsHostMdblistConnectedToast => 'MDBlist connecté !';

  @override
  String addonsHostMdblistConnectedAsToast(String username) {
    return 'MDBlist connecté en tant que $username !';
  }

  @override
  String get addonsHostMdblistInvalidKeyError => 'Clé API MDBlist invalide';

  @override
  String get addonsHostMdblistKeyRemovedToast => 'Clé API MDBlist supprimée';

  @override
  String get addonsHostMdblistIntro =>
      'Notes agrégées d\'IMDb, TMDB, Trakt, Letterboxd, RT et plus encore';

  @override
  String get addonsHostMdblistConnectedStatus => 'Connecté';

  @override
  String addonsHostMdblistConnectedAsStatus(String username) {
    return 'Connecté en tant que $username';
  }

  @override
  String get addonsHostMdblistRemoveKeyButton => 'Supprimer la clé API';

  @override
  String get addonsHostMdblistKeyLabel => 'Clé API MDBlist';

  @override
  String get addonsHostMdblistKeyHint =>
      'Collez votre clé API depuis mdblist.com';

  @override
  String get addonsHostMdblistSaveKeyButton => 'Enregistrer la clé API';

  @override
  String get addonsHostPlayerGroupLabel => 'Lecteur';

  @override
  String get addonsHostPlaybackEngineTitle => 'Moteur films et séries';

  @override
  String get addonsHostPlaybackEngineSubtitle =>
      'Utilisé pour Accueil, Recherche, Anime, Asian Drama et les films/séries IPTV. L\'IPTV en direct a son propre réglage dans IPTV.';

  @override
  String get addonsHostPlaybackAudioLangTitle => 'Langue audio préférée';

  @override
  String get addonsHostPlaybackAudioLangSubtitle =>
      'Passer à une piste audio correspondante au début de la lecture. Choisir \"None\" pour garder la piste par défaut du flux.';

  @override
  String get addonsHostPlaybackSubtitleLangTitle =>
      'Langue des sous-titres préférée';

  @override
  String get addonsHostPlaybackSubtitleLangSubtitle =>
      'Privilégier cette langue pour les sous-titres intégrés ou en ligne. Les pistes intégrées passent en premier si elles correspondent. Choisir \"None\" pour démarrer sans sous-titres.';

  @override
  String get addonsHostPlaybackAvoidAudioTitle =>
      'Éviter l\'audio non pris en charge (Atmos / TrueHD / 7.1)';

  @override
  String get addonsHostPlaybackAvoidAudioSubtitle =>
      'Se rabattre sur AC-3, E-AC-3 ou AAC quand Atmos, TrueHD ou 7.1 n\'est pas pris en charge.';

  @override
  String get addonsHostPlaybackAutoNextTitle => 'Épisode suivant automatique';

  @override
  String get addonsHostPlaybackAutoNextSubtitle =>
      'Lancer l\'épisode suivant à la fin de celui en cours. Aussi disponible dans le panneau Épisodes du lecteur.';

  @override
  String get addonsHostPlaybackAutoSkipIntroTitle =>
      'Passer l\'intro automatiquement';

  @override
  String get addonsHostPlaybackAutoSkipIntroSubtitle =>
      'Passer automatiquement les intros et les résumés quand les repères de temps sont disponibles.';

  @override
  String get addonsHostPlaybackContentWarningsTitle =>
      'Avertissements de contenu';

  @override
  String get addonsHostPlaybackContentWarningsSubtitle =>
      'Afficher les classifications de contenu IMDb (nudité, violence, etc.) au début de la lecture.';

  @override
  String get addonsHostPlaybackBackgroundTitle => 'Lecture en arrière-plan';

  @override
  String get addonsHostPlaybackBackgroundDesktopSubtitle =>
      'Continuer la lecture des films, séries et IPTV quand Forja est en arrière-plan.';

  @override
  String get addonsHostPlaybackBackgroundMobileSubtitle =>
      'Continuer la lecture des films, séries et IPTV quand Forja est en arrière-plan. (la lecture se met en pause jusqu\'à votre retour).';

  @override
  String get addonsHostPlaybackRemoteSoundsTitle =>
      'Sons de clic de la télécommande';

  @override
  String get addonsHostPlaybackRemoteSoundsSubtitle =>
      'Jouer un court clic système quand vous déplacez le focus du D-pad ou appuyez sur OK. Désactivé pendant la lecture d\'une vidéo.';

  @override
  String get addonsHostPlaybackAutoPipTitle =>
      'Image dans l\'image automatique';

  @override
  String get addonsHostPlaybackAutoPipSubtitle =>
      'Passer en image dans l\'image quand vous changez d\'espace (macOS) ou de bureau virtuel (Windows) pendant la lecture. Le bouton PiP du lecteur reste utilisable à tout moment.';

  @override
  String get addonsHostPlaybackMiniPlayerTitle => 'Échap vers le mini-lecteur';

  @override
  String get addonsHostPlaybackMiniPlayerSubtitle =>
      'Quand Échap quitterait le lecteur, passer plutôt au mini-lecteur intégré. Désactivé par défaut. Le bouton mini en haut à droite fonctionne toujours. Différent de l\'image dans l\'image.';

  @override
  String get addonsHostPlaybackMaxQualityTitle => 'Qualité max du flux';

  @override
  String get addonsHostPlaybackMaxQualitySubtitle =>
      'Limiter la qualité du flux Auto et le débit de départ HLS. Auto vise une première image plus rapide. Choisir 4K pour le palier le plus élevé.';

  @override
  String get addonsHostPortalEngineTitle => 'Moteur IPTV';

  @override
  String get addonsHostPortalEngineAndroidSubtitle =>
      'Chaînes en direct uniquement. Ne change pas Films et séries ni Live Sports.';

  @override
  String get addonsHostPortalEngineDesktopSubtitle =>
      'Chaînes en direct uniquement. HLS préfère AVPlayer (Mac) ou VLC (Windows) quand disponible ; MPEG-TS utilise MediaKit.';

  @override
  String get addonsHostPortalEpgTitle => 'Guide des programmes IPTV (EPG)';

  @override
  String get addonsHostPortalEpgSubtitle =>
      'Afficher les infos EN COURS et À SUIVRE dans le lecteur et le navigateur de chaînes.';

  @override
  String get addonsHostPortalMaxQualityTitle => 'Qualité max IPTV en direct';

  @override
  String get addonsHostPortalMaxQualitySubtitle =>
      'ExoPlayer uniquement. Auto utilise la pleine qualité du portail. Limiter à 1080p, 720p ou 480p uniquement sur les appareils peu puissants.';

  @override
  String get addonsHostPortalRecoveryTitle => 'Reprise IPTV en direct';

  @override
  String get addonsHostPortalRecoverySubtitle =>
      'ExoPlayer uniquement. Façon dont les chaînes en direct se reconnectent après un blocage. Auto choisit selon la source. Stable impose une seule politique. Classic utilise des minuteurs de gel. MediaKit ignore ce réglage (reconnexion ffmpeg). S\'applique à la prochaine ouverture du lecteur.';

  @override
  String get addonsHostPortalReopenStallTitle =>
      'Rouvrir en cas de blocage du tampon';

  @override
  String get addonsHostPortalReopenStallSubtitle =>
      'Mode Stable d\'ExoPlayer uniquement. Se reconnecter quand l\'image se fige même si le cache signale encore des données. Laisser désactivé sauf besoin. S\'applique à la prochaine ouverture du lecteur.';

  @override
  String get addonsHostPortalMatchRefreshTitle =>
      'Adapter la fréquence d\'affichage IPTV';

  @override
  String get addonsHostPortalMatchRefreshSubtitle =>
      'MediaKit uniquement. Adapter la fréquence de la TV à celle de la chaîne (par exemple 50 Hz pour 50 i/s). Aide contre les saccades en 4K. Peut faire clignoter brièvement le HDMI après la première image. S\'applique à la prochaine ouverture du lecteur.';

  @override
  String get addonsHostPortalLiveBufferTitle => 'Tampon IPTV en direct';

  @override
  String get addonsHostPortalLiveBufferSubtitle =>
      'MediaKit uniquement. Tampon en direct en avance sur la lecture. Auto utilise 30 s (comme sur ordinateur). Manuel 15–30 s. Aide contre les coupures, pas contre les saccades d\'image. S\'applique à la prochaine ouverture du lecteur.';

  @override
  String get addonsHostTorrentSearchGroupLabel => 'Recherche de torrents';

  @override
  String get addonsHostTorrentInstallPackHint =>
      'Installez le pack Torrent de ForjaHQ dans Paramètres → Forja Packs et activez les indexeurs par plugin.';

  @override
  String get addonsHostTorrentSortTitle => 'Ordre de tri par défaut';

  @override
  String get addonsHostTorrentSortSubtitle =>
      'Façon dont les résultats torrent sont triés automatiquement.';

  @override
  String get addonsHostTorrentFlareSolverrNote =>
      'UIndex est derrière Cloudflare. Pointez vers une instance locale de FlareSolverr ou Byparr (même API /v1 que les indexeurs Prowlarr).';

  @override
  String get addonsHostTorrentEngineGroupLabel => 'Moteur torrent';

  @override
  String addonsHostTorrentDiskCacheTitle(int gb) {
    return 'Cache disque : $gb Go';
  }

  @override
  String get addonsHostTorrentDiskCacheSubtitle =>
      'Données torrent maximales sur le disque. Le fichier en cours de lecture n\'est jamais supprimé. Les téléchargements inactifs les plus anciens sont supprimés au-delà de cette taille.';

  @override
  String addonsHostTorrentGbLabel(int gb) {
    return '$gb Go';
  }

  @override
  String addonsHostTorrentConnectionsTitle(int count) {
    return 'Connexions par torrent : $count';
  }

  @override
  String get addonsHostTorrentConnectionsSubtitle =>
      'Une valeur plus basse (5–25) donne souvent un meilleur streaming sur les essaims à beaucoup de seeders.';

  @override
  String get addonsHostSimklLoginUnavailableError =>
      'La connexion à Simkl n\'est pas disponible dans cette version';

  @override
  String get addonsHostSimklLoginStartFailedError =>
      'Échec du démarrage de la connexion à Simkl';

  @override
  String addonsHostSimklCodeCopiedToast(String code, String url) {
    return 'Code $code copié. Ouverture de $url…';
  }

  @override
  String get addonsHostSimklLoggedInToast => 'Connecté à Simkl !';

  @override
  String addonsHostSimklLoggedInAsToast(String username) {
    return 'Connecté à Simkl en tant que $username !';
  }

  @override
  String get addonsHostSimklLoggedOutToast => 'Déconnecté de Simkl';

  @override
  String get addonsHostSimklPickSyncModeError =>
      'Choisissez d\'abord le mode de synchronisation des listes';

  @override
  String addonsHostSimklSyncError(String error) {
    return 'Erreur de synchronisation Simkl : $error';
  }

  @override
  String get addonsHostSimklSyncedKeptLocal => 'Local conservé';

  @override
  String get addonsHostSimklSyncedUsedSimkl => 'Simkl utilisé';

  @override
  String get addonsHostSimklSyncedMerged => 'Fusionné';

  @override
  String get addonsHostSimklSyncedMergedDeleted => 'Fusionné + supprimé';

  @override
  String get addonsHostSimklSyncedGeneric => 'Synchronisé';

  @override
  String addonsHostSimklSyncSummaryToast(
    String mode,
    int listExported,
    int listImported,
    String removed,
    int progress,
    int movies,
    int epsExported,
    int epsImported,
  ) {
    return '$mode · liste ↑$listExported ↓$listImported$removed, progression $progress, films $movies, épisodes ↑$epsExported ↓$epsImported';
  }

  @override
  String get addonsHostSimklIntro =>
      'Synchronisez votre liste de suivi et votre historique avec Simkl';

  @override
  String get addonsHostSimklConnectedStatus => 'Connecté';

  @override
  String addonsHostSimklConnectedAsStatus(String username) {
    return 'Connecté en tant que $username';
  }

  @override
  String get addonsHostSimklSyncModeTitle =>
      'Comment synchroniser les listes ?';

  @override
  String get addonsHostSimklSyncModeSubtitleAuto =>
      'Enregistré pour Synchroniser maintenant et la synchro auto de Ma liste';

  @override
  String get addonsHostSimklSyncModeSubtitle =>
      'Enregistré pour Synchroniser maintenant';

  @override
  String get addonsHostSimklAutoSyncTitle =>
      'Synchro auto des listes dans Ma liste';

  @override
  String addonsHostSimklAutoSyncSubtitle(String mode) {
    return 'À l\'ouverture de Ma liste, synchroniser avec $mode et actualiser la bibliothèque en cache';
  }

  @override
  String get addonsHostSimklSyncingButton => 'Synchronisation...';

  @override
  String get addonsHostSimklSyncNowButton => 'Synchroniser maintenant';

  @override
  String get addonsHostSimklLogoutButton => 'Se déconnecter de Simkl';

  @override
  String get addonsHostSimklEnterCodePrompt =>
      'Allez à l\'adresse ci-dessous et saisissez ce code :';

  @override
  String get addonsHostSimklWaitingAuth => 'En attente d\'autorisation...';

  @override
  String get addonsHostSimklLoginButton => 'Se connecter avec Simkl';

  @override
  String get addonsHostLanUnpairButton => 'Dissocier';

  @override
  String get addonsHostLanRemoveTorrentError =>
      'Impossible de supprimer le torrent';

  @override
  String get addonsHostLanRemoveTorrentToast =>
      'Entrée du cache torrent supprimée';

  @override
  String get addonsHostLanClearCacheError =>
      'Impossible de vider le cache torrent';

  @override
  String get addonsHostLanClearCacheToast => 'Cache torrent vidé';

  @override
  String get addonsHostLanServerStartFailedError =>
      'Échec du démarrage du serveur LAN';

  @override
  String addonsHostLanServerStartFailedDetailError(String detail) {
    return 'Échec du démarrage du serveur LAN : $detail';
  }

  @override
  String get addonsHostLanNoDesktopFoundInfo =>
      'Aucun ordinateur trouvé. Saisissez l\'IP et le port depuis Paramètres → LAN sur l\'ordinateur.';

  @override
  String get addonsHostLanEnterPairDetailsInfo =>
      'Saisissez l\'adresse de l\'ordinateur, le port et le code à 6 chiffres';

  @override
  String get addonsHostLanPairFailedError =>
      'Échec de l\'association. Vérifiez le code, l\'IP et que le LAN est activé sur l\'ordinateur.';

  @override
  String get addonsHostLanPairedToast =>
      'Associé. Activez Torrent direct dans Paramètres → Lecture.';

  @override
  String get addonsHostLanCodeCopiedToast => 'Code copié';

  @override
  String get addonsHostLanAddressCopiedToast => 'Adresse copiée';

  @override
  String addonsHostLanPortOnlyLabel(int port) {
    return 'port $port';
  }

  @override
  String addonsHostLanAddressMoreLabel(String address, int more) {
    return '$address (+$more autres)';
  }

  @override
  String get addonsHostLanIntroDesktop =>
      'Transformez ce PC en serveur LAN Forja. Associez vos TV et téléphones une fois. Ils choisissent les torrents ; cet ordinateur télécharge et diffuse.';

  @override
  String get addonsHostLanIntroClient =>
      'Associez-vous une fois à un Forja sur ordinateur du même Wi‑Fi. Ensuite, les sources torrent de cet appareil sont lues via l\'ordinateur.';

  @override
  String get addonsHostLanEnableServerTitle => 'Activer le serveur LAN';

  @override
  String addonsHostLanListeningSubtitle(String address) {
    return 'À l\'écoute · $address';
  }

  @override
  String get addonsHostLanServerOffSubtitle =>
      'Désactivé. Les TV ne peuvent pas utiliser cet ordinateur pour les torrents';

  @override
  String get addonsHostLanDesktopAddressHeader => 'ADRESSE DE L\'ORDINATEUR';

  @override
  String get addonsHostLanDesktopAddressHint =>
      'Sur la TV : Paramètres → LAN → saisissez cette IP et ce port si Découvrir ne trouve pas ce PC.';

  @override
  String addonsHostLanNoIpDetected(int port) {
    return 'Port $port. Impossible de détecter une IP LAN. Vérifiez le Wi‑Fi ou l\'Ethernet.';
  }

  @override
  String get addonsHostLanPairingCodeHeader => 'CODE D\'ASSOCIATION';

  @override
  String get addonsHostLanPairingCodeHint =>
      'Sur la TV : Paramètres → LAN → saisissez ce code (valable ~5 minutes, usage unique).';

  @override
  String get addonsHostLanCopyTooltip => 'Copier';

  @override
  String get addonsHostLanNewCodeTooltip => 'Nouveau code';

  @override
  String get addonsHostLanPairedDevicesHeader => 'APPAREILS ASSOCIÉS';

  @override
  String get addonsHostLanReloadDevicesTooltip =>
      'Recharger les appareils associés';

  @override
  String get addonsHostLanNoDevicesPaired =>
      'Aucune TV ni aucun téléphone associé pour le moment.';

  @override
  String get addonsHostLanRevokeHint =>
      'Révoquer pour obliger cet appareil à s\'associer de nouveau.';

  @override
  String get addonsHostLanWaitingForDevice =>
      'En attente de la saisie du code sur un appareil…';

  @override
  String get addonsHostLanDeviceFallback => 'Appareil';

  @override
  String get addonsHostLanRevokeButton => 'Révoquer';

  @override
  String get addonsHostLanTorrentActivityHeader => 'ACTIVITÉ TORRENT';

  @override
  String get addonsHostLanClearAllButton => 'Tout effacer';

  @override
  String get addonsHostLanTorrentActivityHint =>
      'Torrents ouverts par les TV/téléphones associés. Supprimer efface le téléchargement en cache.';

  @override
  String addonsHostLanCacheOnDisk(String size) {
    return 'Cache sur disque : $size';
  }

  @override
  String get addonsHostLanActiveTorrentFallback => 'Torrent actif';

  @override
  String get addonsHostLanNoTorrentsYet =>
      'Aucun torrent LAN pour le moment. Lancez-en un depuis une TV associée.';

  @override
  String get addonsHostLanServingNow =>
      'En cours de diffusion (pas encore dans l\'historique).';

  @override
  String addonsHostLanPeersChip(int count) {
    return '$count pairs';
  }

  @override
  String get addonsHostLanDeleteCachedTooltip =>
      'Supprimer le téléchargement en cache';

  @override
  String get addonsHostLanPairedStatus => 'Associé';

  @override
  String get addonsHostLanNotPairedStatus => 'Non associé';

  @override
  String get addonsHostLanDesktopOnline => 'Ordinateur en ligne';

  @override
  String get addonsHostLanDesktopOffline => 'Ordinateur hors ligne';

  @override
  String get addonsHostLanPlayingStatus => 'lecture en cours';

  @override
  String addonsHostLanPairedAddressNote(String host, String port) {
    return '$host:$port. Les torrents sont lus via l\'ordinateur.';
  }

  @override
  String get addonsHostLanPairOnceNote =>
      'Associez-vous une fois. Ouvrez ensuite Sources → Torrents sur un titre.';

  @override
  String get addonsHostLanReloadStatusTooltip =>
      'Recharger l\'état de l\'ordinateur';

  @override
  String get addonsHostLanFindDesktopHeader => 'TROUVER L\'ORDINATEUR';

  @override
  String get addonsHostLanSearchingButton => 'Recherche…';

  @override
  String get addonsHostLanDiscoverButton => 'Découvrir sur le Wi‑Fi';

  @override
  String addonsHostLanPortValue(int port) {
    return 'Port $port';
  }

  @override
  String get addonsHostLanUseButton => 'Utiliser';

  @override
  String get addonsHostLanEnterManuallyHeader => 'OU SAISIR MANUELLEMENT';

  @override
  String get addonsHostLanDesktopIpLabel => 'IP de l\'ordinateur';

  @override
  String get addonsHostLanPortLabel => 'Port';

  @override
  String get addonsHostLanPortHint =>
      'Affiché sous Activer le serveur LAN sur l\'ordinateur';

  @override
  String get addonsHostLanCodeLabel => 'Code à 6 chiffres';

  @override
  String get addonsHostLanCodeHint =>
      'Depuis Paramètres → LAN sur l\'ordinateur';

  @override
  String get addonsHostLanPairButton => 'S\'associer à l\'ordinateur';

  @override
  String get addonsHostLanLocalTorrentTitle =>
      'Autoriser le torrent local sur cet appareil';

  @override
  String get addonsHostLanLocalTorrentSubtitle =>
      'Avancé. Utilise le moteur de l\'appareil plutôt que l\'ordinateur. Laisser désactivé sur TV.';

  @override
  String get addonsHostProvStremioGroupLabel => 'Addons Stremio';

  @override
  String get addonsHostProvNuvioGroupLabel => 'Addons Nuvio';

  @override
  String get addonsHostProvAddonInstalledToast => 'Addon installé';

  @override
  String get addonsHostProvInstallFailedError =>
      'Échec de l\'installation de l\'addon. Vérifiez l\'URL.';

  @override
  String addonsHostProvGenericError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get addonsHostProvAddonRemovedToast => 'Addon supprimé';

  @override
  String get addonsHostProvInstallStremioLabel => 'Installer un addon Stremio';

  @override
  String get addonsHostProvInstallButton => 'Installer';

  @override
  String get addonsHostProvInstalledAddonsLabel => 'Addons installés';

  @override
  String get addonsHostProvUntitledAddon => 'Addon sans titre';

  @override
  String get addonsHostProvSourcesChip => 'Sources';

  @override
  String get addonsHostProvInstallNuvioLabel => 'Installer un addon Nuvio';

  @override
  String addonsHostProvNuvioInstalledToast(String name, int count) {
    return '$name installé ($count scrapers)';
  }

  @override
  String addonsHostProvInstallFailedDetailError(String error) {
    return 'Échec de l\'installation : $error';
  }

  @override
  String get addonsHostProvNuvioRemovedToast => 'Addon Nuvio supprimé';

  @override
  String get addonsHostProvBaseUrlLabel => 'URL de base';

  @override
  String get addonsHostProvApiKeyLabel => 'Clé API';

  @override
  String get addonsHostProvJackettApiKeyHint => 'Saisir la clé API Jackett';

  @override
  String get addonsHostProvProwlarrApiKeyHint => 'Saisir la clé API Prowlarr';

  @override
  String get addonsHostProvTestConnectionButton => 'Tester la connexion';

  @override
  String get addonsHostProvSaveButton => 'Enregistrer';

  @override
  String get addonsHostProvFilterByTagLabel => 'Filtrer par tag';

  @override
  String get addonsHostProvLoadTagsHint =>
      'Utilisez le bouton Tester la connexion pour charger les tags disponibles.';

  @override
  String get addonsHostProvNoTagsFound =>
      'Aucun tag trouvé dans Prowlarr. Ajoutez des tags à vos indexeurs pour utiliser ce filtre.';

  @override
  String get addonsHostProvTagFilterHint =>
      'Limiter les recherches aux indexeurs ayant les tags sélectionnés. Ne rien sélectionner pour interroger tous les indexeurs.';

  @override
  String get addonsHostProvAllIndexersSearched =>
      'Tous les indexeurs seront interrogés.';

  @override
  String get addonsHostProvEnterUrlAndKeyResult =>
      '❌ Saisissez l\'URL de base et la clé API';

  @override
  String addonsHostProvTestErrorResult(String error) {
    return '❌ Erreur : $error';
  }

  @override
  String get addonsHostProvJackettSavedToast =>
      'Paramètres Jackett enregistrés';

  @override
  String get addonsHostProvProwlarrSavedToast =>
      'Paramètres Prowlarr enregistrés';

  @override
  String get addonsHostProvScraperFallback => 'Scraper';

  @override
  String addonsHostProvNuvioLeanSubtitle(String version) {
    return 'Développer pour télécharger les scrapers · v$version';
  }

  @override
  String addonsHostProvNuvioScrapersSubtitle(int count, String version) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scrapers · v$version',
      one: '$count scraper · v$version',
    );
    return '$_temp0';
  }

  @override
  String addonsHostProvNuvioLoadedToast(String name, int count) {
    return '$name chargé ($count scrapers)';
  }

  @override
  String get addonsHostProvDownloadingScrapers =>
      'Téléchargement des scrapers…';

  @override
  String get addonsHostProvLoadScrapersFailed =>
      'Impossible de charger les scrapers';

  @override
  String get addonsHostProvRetryButton => 'Réessayer';

  @override
  String get addonsHostProvRemoveConfirmTitle => 'Supprimer cet addon ?';

  @override
  String get addonsHostProvYesTooltip => 'Oui';

  @override
  String get addonsHostProvNoTooltip => 'Non';

  @override
  String get addonsHostProvRemoveAddonTooltip => 'Supprimer l\'addon';

  @override
  String get aboutUpdatesGroupLabel => 'Mises à jour';

  @override
  String get aboutPrivacyGroupLabel => 'Confidentialité';

  @override
  String get aboutDeveloperGroupLabel => 'Développeur';

  @override
  String get aboutVerifySentryTitle => 'Vérifier Sentry';

  @override
  String get aboutVerifySentrySubtitleActive =>
      'Envoyer une exception de test au projet Forja Flutter';

  @override
  String get aboutVerifySentrySubtitleInactive =>
      'Activez d\'abord les rapports de plantage, puis appuyez à nouveau';

  @override
  String get aboutVerifySentrySent =>
      'Événement de test envoyé - consultez les Issues Sentry';

  @override
  String get aboutVerifyPostHogTitle => 'Vérifier PostHog';

  @override
  String get aboutVerifyPostHogSubtitleActive =>
      'Envoyer analytics_verify à votre projet PostHog';

  @override
  String get aboutVerifyPostHogSubtitleInactive =>
      'Activez d\'abord les statistiques d\'utilisation, puis appuyez à nouveau';

  @override
  String get aboutVerifyPostHogSent =>
      'Événement de test envoyé - consultez PostHog → Activity';

  @override
  String get aboutCheckForUpdatesBlurb =>
      'Rechercher les nouvelles versions de Forja';

  @override
  String get aboutCheckingButton => 'Vérification...';

  @override
  String get aboutCheckForUpdatesButton => 'Rechercher des mises à jour';

  @override
  String get aboutCheckForUpdatesFailed =>
      'Impossible de rechercher les mises à jour.';

  @override
  String get aboutUpToDate => 'Vous avez la dernière version';

  @override
  String aboutCheckForUpdatesError(String error) {
    return 'Échec de la recherche de mises à jour : $error';
  }

  @override
  String get aboutCrashReportingTitle => 'Rapports de plantage';

  @override
  String get aboutTelemetryDebugSubtitle =>
      'Inactif dans les versions de débogage. Votre choix est enregistré pour la version finale.';

  @override
  String get aboutTelemetryUnavailableSubtitle =>
      'Indisponible dans cette version. Votre choix est quand même enregistré.';

  @override
  String get aboutCrashReportingSubtitle =>
      'Envoie les détails des plantages pour corriger les bogues. Aucun mot de passe ni lien de flux.';

  @override
  String get aboutCrashReportingSavedDebug =>
      'Enregistré. Les rapports de plantage restent désactivés dans les versions de débogage.';

  @override
  String get aboutCrashReportingUnavailable =>
      'Les rapports de plantage ne sont pas encore disponibles dans cette version.';

  @override
  String get aboutCrashReportingOn => 'Rapports de plantage activés';

  @override
  String get aboutCrashReportingOff => 'Rapports de plantage désactivés';

  @override
  String get aboutCrashReportingUpdateFailed =>
      'Impossible de modifier les rapports de plantage';

  @override
  String get aboutProductAnalyticsTitle => 'Statistiques d\'utilisation';

  @override
  String get aboutProductAnalyticsSubtitle =>
      'Partage votre utilisation de Forja pour nous aider à l\'améliorer.';

  @override
  String get aboutProductAnalyticsSavedDebug =>
      'Enregistré. Les statistiques d\'utilisation restent désactivées dans les versions de débogage.';

  @override
  String get aboutProductAnalyticsUnavailable =>
      'Les statistiques d\'utilisation ne sont pas encore disponibles dans cette version.';

  @override
  String get aboutProductAnalyticsOn => 'Statistiques d\'utilisation activées';

  @override
  String get aboutProductAnalyticsOff =>
      'Statistiques d\'utilisation désactivées';

  @override
  String get aboutProductAnalyticsUpdateFailed =>
      'Impossible de modifier les statistiques d\'utilisation';

  @override
  String get aboutKeychainRowTitle => 'Stocker les secrets dans le Trousseau';

  @override
  String get aboutKeychainRowSubtitle =>
      'Désactivé par défaut (fichier local de l\'app). Activez pour utiliser le Trousseau macOS. Forja explique d\'abord ; le système peut demander votre mot de passe une fois.';

  @override
  String get aboutKeychainEnabled => 'Trousseau activé pour les secrets';

  @override
  String get aboutKeychainLocalStorage => 'Stockage dans un fichier local';

  @override
  String get aboutKeychainConsentTitle => 'Utiliser le Trousseau macOS ?';

  @override
  String get aboutKeychainConsentBodyStore =>
      'Forja peut stocker les jetons de connexion et les clés d\'API dans le Trousseau macOS au lieu d\'un fichier local de l\'app.';

  @override
  String get aboutKeychainConsentBodyPrompt =>
      'Après votre accord, macOS peut afficher une fois sa propre fenêtre de mot de passe. Elle peut mentionner \"flutter_secure_storage_service\". Ce nom désigne le coffre sécurisé de Forja, pas une autre app. Choisissez Toujours autoriser si vous faites confiance à Forja.';

  @override
  String get aboutKeychainConsentBodyLocal =>
      'Vous pouvez continuer à utiliser le stockage dans un fichier local (par défaut), sans demande du Trousseau.';

  @override
  String get aboutKeychainConsentKeepLocal => 'Garder le fichier local';

  @override
  String get aboutKeychainConsentUseKeychain => 'Utiliser le Trousseau';

  @override
  String get addonsPlaybackTitle => 'Lecture';

  @override
  String get addonsPlaybackSubtitle => 'Qualité, audio, lecture auto';

  @override
  String get addonsTorrentTitle => 'Torrent direct';

  @override
  String get addonsTorrentSubtitle => 'Jackett, Prowlarr, moteur torrent';

  @override
  String get addonsStremioSubtitle => 'Addons Stremio';

  @override
  String get addonsNuvioSubtitle => 'Scrapers Nuvio';

  @override
  String get addonsConnectedServicesTitle => 'Services connectés';

  @override
  String get addonsConnectedServicesSubtitle => 'Simkl ; MDBlist (admin)';

  @override
  String get addonsLanSubtitle => 'Serveur de bureau, jumelage, relais torrent';

  @override
  String addonsPackSettingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réglages de packs',
      one: 'Paramètres du pack',
    );
    return '$_temp0';
  }

  @override
  String get addonsBuiltInGroupLabel => 'Addons intégrés';

  @override
  String get addonsPackSettingsGroupLabel => 'Paramètres des packs';

  @override
  String get addonsNoPackSettings =>
      'Aucun réglage de pack pour l\'instant. Activez des packs avec des réglages d\'addon dans Forja Packs.';

  @override
  String get addonsPackCancel => 'Annuler';

  @override
  String addonsPackActionFailed(String action, String title) {
    return 'Impossible d\'exécuter $action sur $title';
  }

  @override
  String get addonsPackSelectAll => 'Tout';

  @override
  String get addonsPackSelectNone => 'Aucun';

  @override
  String get addonsPackAutoOption => 'Auto';

  @override
  String get addonsPackAuthBrowserOpenFailed =>
      'Impossible d\'ouvrir le navigateur';

  @override
  String get addonsPackAuthBrowserTimedOut =>
      'Délai dépassé en attendant la session Shahid';

  @override
  String get addonsPackAuthBrowserScriptCopied =>
      'Copié — dans l\'onglet Shahid, ouvrez la Console (⌘⌥J), collez, Entrée';

  @override
  String get addonsPackAuthBrowserDefaultHint =>
      'Connectez-vous à Shahid dans votre navigateur (déjà connecté, c\'est bon).';

  @override
  String get addonsPackAuthBrowserStep1Open =>
      '1. Shahid est ouvert dans votre navigateur.';

  @override
  String get addonsPackAuthBrowserStep1Opening =>
      '1. Ouverture de votre navigateur…';

  @override
  String get addonsPackAuthBrowserStep2 =>
      '2. Dans cet onglet Shahid : ouvrez la Console (⌘⌥J / Ctrl+Maj+J), collez, Entrée.';

  @override
  String get addonsPackAuthBrowserStep3Waiting =>
      '3. En attente de la session… puis Forja affiche Connecté (vous pouvez fermer l\'onglet Shahid).';

  @override
  String get addonsPackAuthBrowserStep3Stopped =>
      '3. Attente arrêtée — copiez à nouveau ou utilisez le mot de passe.';

  @override
  String get addonsPackAuthBrowserCopyScript => 'Copier le script de connexion';

  @override
  String get addonsPackAuthBrowserOpenAgain => 'Rouvrir Shahid';

  @override
  String get addonsPackAuthBrowserHidePassword => 'Masquer e-mail/mot de passe';

  @override
  String get addonsPackAuthBrowserUsePassword => 'Utiliser e-mail/mot de passe';

  @override
  String get addonsPackAuthBrowserConnect => 'Connecter';

  @override
  String addonsPackAuthPinUnavailable(String label) {
    return 'La connexion par code PIN pour $label n\'est pas disponible dans cette version';
  }

  @override
  String addonsPackAuthNoMethods(String label) {
    return 'Aucune méthode de connexion fournie par $label';
  }

  @override
  String addonsPackAuthConnectedTo(String label) {
    return 'Connecté à $label';
  }

  @override
  String addonsPackAuthNoUrl(String label) {
    return 'Aucune URL de connexion fournie par $label';
  }

  @override
  String addonsPackAuthSignInTo(String label) {
    return 'Se connecter à $label';
  }

  @override
  String addonsPackAuthSignedOutOf(String label) {
    return 'Déconnecté de $label';
  }

  @override
  String addonsPackAuthConnectedAs(String who) {
    return 'Connecté en tant que $who';
  }

  @override
  String get addonsPackAuthConnected => 'Connecté';

  @override
  String addonsPackAuthLogoutFrom(String label) {
    return 'Se déconnecter de $label';
  }

  @override
  String addonsPackAuthLoginWith(String label) {
    return 'Se connecter avec $label';
  }

  @override
  String addonsPackAuthLoginDialogTitle(String title) {
    return 'Connexion · $title';
  }

  @override
  String get addonsPackAuthLoginButton => 'Se connecter';

  @override
  String get addonsPackGreenPlayIntro =>
      'Fournisseurs Forja préférés pour le bouton Play vert. Ils sont essayés en premier ; une liste vide met en concurrence tous les fournisseurs Forja activés.';

  @override
  String get addonsPackGreenPlayEmpty =>
      'Aucun fournisseur préféré — le Play vert met en concurrence tous les plugins Forja activés.';

  @override
  String get addonsPackGreenPlayRemove => 'Retirer';

  @override
  String get addonsPackGreenPlayAddPreferred => 'Ajouter un favori';

  @override
  String get addonsPackGreenPlayAddDialogTitle =>
      'Ajouter un fournisseur préféré';

  @override
  String get addonsPackGreenPlaySearchLabel => 'Rechercher';

  @override
  String get addonsPackGreenPlaySearchHint => 'Nom du fournisseur';

  @override
  String get addonsPackGreenPlayNoProviders => 'Aucun fournisseur Forja activé';

  @override
  String get addonsPackGreenPlayNoMatches => 'Aucun résultat';

  @override
  String get dataStreamSubtitleTorrent =>
      'URL de fournisseurs de flux enregistrées, fichiers temporaires torrent et tampons de recherche. La prochaine lecture les résout à nouveau. Les réglages et l\'historique de visionnage restent.';

  @override
  String get dataStreamSubtitle =>
      'URL de fournisseurs de flux enregistrées et tampons de recherche. La prochaine lecture les résout à nouveau. Les réglages et l\'historique de visionnage restent.';

  @override
  String get dataStreamBodyTorrent =>
      'Efface les extraits de flux enregistrés, le cache de téléchargement torrent et les tampons de recherche temporaires du profil actuel (ou Invité).\n\nL\'historique de visionnage, les scores des fournisseurs et les réglages ne sont pas touchés. Les fichiers temporaires torrent sont partagés sur cet appareil.';

  @override
  String get dataStreamBody =>
      'Efface les extraits de flux enregistrés et les tampons de recherche temporaires du profil actuel (ou Invité).\n\nL\'historique de visionnage, les scores des fournisseurs et les réglages ne sont pas touchés.';

  @override
  String get dataGroupSafeToClear => 'Sans risque à effacer';

  @override
  String get dataStreamCacheTitle => 'Cache des flux';

  @override
  String get dataStreamClearTitle => 'Effacer le cache des flux ?';

  @override
  String get dataClear => 'Effacer';

  @override
  String get dataStreamCleared => 'Cache des flux effacé';

  @override
  String get dataImagesTitle => 'Images et WebView';

  @override
  String get dataImagesSubtitle =>
      'Vignettes d\'affiches et caches WebView des extracteurs. Libère de l\'espace disque ; les images se retéléchargent au besoin.';

  @override
  String get dataImagesClearTitle => 'Effacer les images et WebView ?';

  @override
  String get dataImagesClearBody =>
      'Efface les affiches en cache et les données d\'extraction WebView sur cet appareil. Vos listes et votre historique de visionnage ne sont pas touchés.';

  @override
  String get dataImagesCleared => 'Cache des images et WebView effacé';

  @override
  String get dataPortalTitle => 'Cache des portails IPTV';

  @override
  String get dataPortalSubtitle =>
      'Catalogues, vérifications de disponibilité et analyses de chaînes. Les portails et favoris restent. Rechargé à la prochaine ouverture.';

  @override
  String get dataPortalClearTitle => 'Effacer le cache des portails IPTV ?';

  @override
  String get dataPortalClearBody =>
      'Efface les catalogues enregistrés, les vérifications de chaînes actives et les résultats d\'analyse de chaînes des portails IPTV du profil actuel (ou Invité).\n\nLes portails enregistrés, les favoris et les playlists M3U ne sont pas touchés.';

  @override
  String get dataPortalCleared => 'Cache des portails IPTV effacé';

  @override
  String get dataUpdatesTitle => 'Mises à jour téléchargées';

  @override
  String get dataUpdatesSubtitle =>
      'Fichiers d\'installation issus de la mise à jour dans l\'app (.dmg, .exe, AppImage). Sans risque à supprimer après l\'installation.';

  @override
  String get dataUpdatesClearTitle => 'Effacer les mises à jour téléchargées ?';

  @override
  String get dataUpdatesClearBody =>
      'Supprime les installateurs de mise à jour que Forja a enregistrés dans Téléchargements, le stockage de l\'app ou le dossier temporaire pendant le téléchargement.\n\nVotre version installée de l\'app et vos réglages ne sont pas touchés.';

  @override
  String get dataUpdatesCleared =>
      'Fichiers de mise à jour téléchargés effacés';

  @override
  String get dataGroupLearned => 'Appris';

  @override
  String get dataScoresTitle => 'Scores des fournisseurs';

  @override
  String get dataScoresSubtitle =>
      'Totaux de fiabilité pour le score dans les réglages et l\'ordre Auto. L\'ordre par glisser-déposer est conservé ; les scores repartent de zéro.';

  @override
  String get dataScoresResetTitle =>
      'Réinitialiser les scores des fournisseurs ?';

  @override
  String get dataScoresResetBody =>
      'Efface la fiabilité apprise de tous les fournisseurs du profil actuel (ou Invité). Le score dans les réglages revient à 0 et Auto réapprend à partir de nouvelles vérifications.\n\nVotre ordre préféré par glisser-déposer n\'est pas modifié.';

  @override
  String get dataScoresResetConfirm => 'Réinitialiser les scores';

  @override
  String get dataScoresReset => 'Scores des fournisseurs réinitialisés';

  @override
  String get dataGroupWatchData => 'Données de visionnage';

  @override
  String get dataContinueTitle => 'Reprendre la lecture';

  @override
  String get dataContinueSubtitle =>
      'Rangées de reprise sur Accueil, Anime et Drames asiatiques. Irréversible pour ce profil.';

  @override
  String get dataContinueClearTitle => 'Effacer la reprise de lecture ?';

  @override
  String get dataContinueClearBody =>
      'Supprime les entrées de reprise de lecture pour les films, séries, anime, drames asiatiques et anime en arabe du profil actuel (ou Invité).\n\nLes autres profils ne sont pas touchés. L\'historique cloud Trakt ou Simkl n\'est pas supprimé. Ma liste et les éléments aimés sont conservés.';

  @override
  String get dataContinueClearConfirm => 'Effacer l\'historique';

  @override
  String get dataContinueCleared => 'Reprise de lecture effacée';

  @override
  String get dataWatchedTitle => 'Marques d\'épisodes vus';

  @override
  String get dataWatchedSubtitle =>
      'Coches « vu » locales dans les listes d\'épisodes. L\'historique en ligne Trakt / Simkl reste.';

  @override
  String get dataWatchedClearTitle => 'Effacer les marques « vu » ?';

  @override
  String get dataWatchedClearBody =>
      'Supprime les coches « vu » locales des épisodes du profil actuel (ou Invité). La progression de reprise est conservée sauf si vous l\'effacez séparément.\n\nTrakt / Simkl peuvent à nouveau afficher des épisodes comme vus après la synchronisation.';

  @override
  String get dataWatchedClearConfirm => 'Effacer les marques';

  @override
  String get dataWatchedCleared => 'Marques « vu » effacées';

  @override
  String dataFailed(String error) {
    return 'Échec : $error';
  }

  @override
  String get dataExportDialogTitle => 'Exporter les réglages';

  @override
  String get dataExported => 'Paramètres exportés';

  @override
  String dataExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get dataImportDialogTitle => 'Importer les réglages';

  @override
  String get dataReadFileFailed => 'Impossible de lire le fichier.';

  @override
  String get dataImportConfirmBody =>
      'Cela écrase vos réglages actuels, y compris les addons, les clés API et les préférences. Continuer ?';

  @override
  String get dataImport => 'Importer';

  @override
  String get dataImported => 'Paramètres importés';

  @override
  String dataImportFailed(String error) {
    return 'Échec de l\'import : $error';
  }

  @override
  String get dataBackupLabel => 'Sauvegarde';

  @override
  String get dataBackupHint =>
      'Exportez ou importez tous vos réglages, addons, clés API et préférences dans un fichier JSON.';

  @override
  String get dataExport => 'Exporter';

  @override
  String packsUpdateAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mises à jour disponibles',
      one: '$count mise à jour disponible',
    );
    return '$_temp0';
  }

  @override
  String get packsUpdateUpToDate => 'Tous les plugins sont à jour';

  @override
  String get packsUpdateMenuBadge => 'Mise à jour disponible';

  @override
  String get packsUpdateChecking => 'Recherche de mises à jour des plugins…';

  @override
  String get packsUpdateUpdating => 'Mise à jour…';

  @override
  String get packsUpdateAll => 'Tout mettre à jour';

  @override
  String get packsUpdateCheckAgain => 'Vérifier à nouveau';

  @override
  String get packsPackDeprecatedTag => 'obsolète';

  @override
  String get packsPackUnavailableHereTag => 'indisponible sur cet appareil';

  @override
  String get packsPluginsMiniLabel => 'Plugins Forja';

  @override
  String packsPackMeta(String kind, int count, String version) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plugins',
      one: '$count plugin',
    );
    return '$kind · $_temp0 · v$version';
  }

  @override
  String get packsPluginUnavailableHere => 'Indisponible sur cet appareil';

  @override
  String get packsLiveTabCatalog => 'Catalogue';

  @override
  String get packsLiveTabProvider => 'Fournisseur';

  @override
  String get packsLiveCatalogSubtitle => 'Programme pour Live Sports';

  @override
  String get packsLiveProviderSubtitle => 'Résolution des flux pour Forja Live';

  @override
  String get featuresDefaultMenu => 'Menu par défaut';

  @override
  String get featuresSetDefaultMenu => 'Définir comme menu par défaut';

  @override
  String get featuresHintLeanback =>
      'OK active ou masque un onglet. L\'étoile définit le menu par défaut. ↑/↓ sur les flèches réorganisent. ↓ reste dans la même colonne.';

  @override
  String get featuresHint =>
      'Afficher, masquer et réorganiser les onglets. Glisser pour réorganiser. Les réglages restent visibles.';

  @override
  String get featuresAlwaysVisible => 'Toujours visible';

  @override
  String get packsChoiceOfficialTitle => 'Packs officiels';

  @override
  String get packsChoiceOfficialSubtitle =>
      'Choisir les packs ForjaHQ à installer';

  @override
  String get packsChoiceCommunityTitle => 'Packs de la communauté';

  @override
  String get packsChoiceCommunitySubtitleCompact =>
      'Parcourir les packs sur le web';

  @override
  String get packsChoiceCommunitySubtitle =>
      'Parcourir et choisir des packs sur le web';

  @override
  String get packsPromptTitleSync => 'Synchroniser les packs';

  @override
  String get packsPromptTitleUninstall => 'Désinstaller des packs';

  @override
  String get packsPromptTitleInstall => 'Installer des packs';

  @override
  String packsPromptInstalledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs installés',
      one: '$count pack installé',
    );
    return '$_temp0';
  }

  @override
  String packsPromptRemovedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs supprimés',
      one: '$count pack supprimé',
    );
    return '$_temp0';
  }

  @override
  String packsPromptFailedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Échec de $count packs — voir les détails ci-dessus',
      one: 'Échec de l\'installation du pack — voir les détails ci-dessus',
    );
    return '$_temp0';
  }

  @override
  String get packsPromptBodyRemote =>
      'Ces packs ont changé sur votre profil depuis un autre appareil. Choisissez ce qu\'il faut appliquer ici. Le reste peut attendre dans Forja Packs.';

  @override
  String get packsPromptBodyLocal =>
      'Choisissez les packs à télécharger sur cet appareil. Vous pourrez installer les autres plus tard depuis cette page.';

  @override
  String get packsPromptWorking => 'En cours…';

  @override
  String packsPromptApply(int install, int uninstall) {
    return 'Appliquer ($install à installer · $uninstall à désinstaller)';
  }

  @override
  String packsPromptUninstallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs',
      one: '$count pack',
    );
    return 'Désinstaller $_temp0';
  }

  @override
  String packsPromptInstallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs',
      one: '$count pack',
    );
    return 'Installer $_temp0';
  }

  @override
  String get packsPromptSelectAll => 'Tout sélectionner';

  @override
  String get packsPromptClear => 'Effacer';

  @override
  String packsPromptSelected(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get packsPromptLocalFolder => 'Dossier local';

  @override
  String packsPromptCommunitySource(String host) {
    return '$host · Source communautaire';
  }

  @override
  String get packsPromptDefaultTitle => 'Pack de plugins';

  @override
  String get packsPromptActionUninstall => 'Désinstaller';

  @override
  String get packsPromptActionInstall => 'Installer';

  @override
  String get packsPromptAlreadyRemoved => 'Déjà supprimé';

  @override
  String get packsPromptAlreadyOnDevice => 'Déjà sur l\'appareil';

  @override
  String get packsPromptNotOnDevice => 'Indisponible sur cet appareil';

  @override
  String get packsPromptCommunity => 'Communauté';

  @override
  String get packsPromptRecommended => 'Recommandé';

  @override
  String get packsGroupLabel => 'Forja Packs';

  @override
  String get packsEmptyNone =>
      'Aucun pack installé. Collez l\'URL d\'un manifeste ci-dessous, ou connectez-vous pour synchroniser depuis votre profil.';

  @override
  String packsInstallFailed(String error) {
    return 'Échec de l\'installation du pack : $error';
  }

  @override
  String get packsRetryInstall => 'Réessayer l\'installation';

  @override
  String get packsManifestHint =>
      'Chaque pack est une URL manifest.json. Forja télécharge le manifeste, puis chaque script de plugin, avant que le pack soit pleinement utilisable.';

  @override
  String get packsAddPackLabel => 'Ajouter un pack';

  @override
  String get packsAddPackHint =>
      'Collez une ou plusieurs URL de manifeste / chemins locaux';

  @override
  String get packsDownloadAll => 'Tout télécharger';

  @override
  String get packsReloadingTooltip => 'Rechargement des packs…';

  @override
  String get packsReload => 'Recharger';

  @override
  String get packsInstall => 'Installer';

  @override
  String get packsPendingDownloads => 'Téléchargements en attente';

  @override
  String get packsInstalledPacks => 'Packs installés';

  @override
  String get packsBadgeRemovedFromProfile => 'Retiré du profil';

  @override
  String get packsActionUninstallNow => 'Désinstaller maintenant';

  @override
  String get packsBadgeInstallLater => 'Installer plus tard';

  @override
  String get packsBadgeInstallFailed => 'Échec de l\'installation';

  @override
  String get packsBadgeDownloading => 'Téléchargement';

  @override
  String get packsBadgePendingDownload => 'Téléchargement en attente';

  @override
  String get packsRetryDownload => 'Réessayer le téléchargement';

  @override
  String get packsToastRefreshed => 'Packs actualisés';

  @override
  String get packsToastRecommendedInstalled =>
      'Packs recommandés déjà installés';

  @override
  String get packsToastFinishPrompt =>
      'Terminez d\'abord l\'invite de pack en cours';

  @override
  String packsToastOfficialInstallFailed(String error) {
    return 'Échec de l\'installation du pack officiel : $error';
  }

  @override
  String packsToastUpdatedTo(String name, String version) {
    return '$name mis à jour vers v$version';
  }

  @override
  String packsToastRefreshedPack(String name, String version) {
    return '$name v$version actualisé';
  }

  @override
  String packsToastRefreshFailed(String error) {
    return 'Échec de l\'actualisation : $error';
  }

  @override
  String packsToastReloadFailed(String name, String error) {
    return 'Échec du rechargement de $name : $error';
  }

  @override
  String packsToastReloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs rechargés',
      one: '$count pack rechargé',
    );
    return '$_temp0';
  }

  @override
  String packsToastDownloadFailed(String name, String error) {
    return 'Échec du téléchargement de $name : $error';
  }

  @override
  String packsToastDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs téléchargés',
      one: '$count pack téléchargé',
    );
    return '$_temp0';
  }

  @override
  String packsToastUpdateFailed(String name, String error) {
    return 'Échec de la mise à jour de $name : $error';
  }

  @override
  String packsToastUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs mis à jour',
      one: '$count pack mis à jour',
    );
    return '$_temp0';
  }

  @override
  String get packsToastInstallFailedDetails =>
      'Échec de l\'installation — voir les détails ci-dessus';

  @override
  String packsToastInstalled(String name, int count) {
    return '$name installé ($count plugins)';
  }

  @override
  String get packsToastPackUninstalled => 'Pack désinstallé';

  @override
  String get packsToastPackRemoved => 'Pack supprimé';

  @override
  String get packsOfficialBadge => 'Officiel';

  @override
  String packsActionUpdateTo(String version) {
    return 'Mettre à jour vers v$version';
  }

  @override
  String get packsActionRefresh => 'Actualiser';

  @override
  String packsFailuresTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Échec de l\'installation de $count packs',
      one: 'Échec de l\'installation du pack',
    );
    return '$_temp0';
  }

  @override
  String get packsDismiss => 'Ignorer';

  @override
  String get packsPendingReady => 'Prêt';

  @override
  String get packsPendingWaiting => 'En attente';

  @override
  String get packsPendingDownload => 'Télécharger';

  @override
  String get packsPendingYes => 'Oui';

  @override
  String get packsPendingNo => 'Non';

  @override
  String get packsPendingRemovePack => 'Supprimer le pack';

  @override
  String packsInstallUpdateAvailable(String version) {
    return 'Mise à jour disponible : v$version';
  }

  @override
  String get packsInstallBannerUpdating => 'Mise à jour des plugins…';

  @override
  String get packsInstallBannerDownloading => 'Téléchargement des plugins…';

  @override
  String get profileLoadFailed =>
      'Impossible de charger le profil. Vérifiez votre connexion et réessayez.';

  @override
  String get profileToastProfileReady => 'Profil prêt';

  @override
  String get profileToastAccountReady => 'Compte prêt';

  @override
  String get profileSignInFailed =>
      'Échec de la connexion. Vérifiez l\'e-mail et le mot de passe, ou la config Supabase.';

  @override
  String get profileWebLoginIncomplete => 'La connexion web n\'a pas abouti.';

  @override
  String get profileWebLoginFailed =>
      'Impossible de terminer la connexion web. Vérifiez que le portail est accessible.';

  @override
  String get profileSignupOpenFailed =>
      'Impossible d\'ouvrir la page d\'inscription.';

  @override
  String get profileCloudNotConfigured =>
      'Le compte cloud n\'est pas configuré dans cette version. Passez SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY via --dart-define.';

  @override
  String get profileAccountLabel => 'Compte';

  @override
  String get profileSignedIn => 'Connecté';

  @override
  String get profileCloudProfileLoading => 'Chargement du profil cloud…';

  @override
  String get profileCloudProfileLoadFailed =>
      'Le profil cloud n\'a pas pu se charger. Réessayez, ou déconnectez-vous pour effacer cette session sur l\'appareil.';

  @override
  String get profileRetryTitle => 'Réessayer';

  @override
  String get profileRetrySubtitle => 'Recharger les profils depuis le cloud';

  @override
  String get profileSignOutTitle => 'Se déconnecter';

  @override
  String get profileSignOutSubtitle =>
      'Effacer la session sur cet appareil même sans réseau';

  @override
  String get profileSyncNoneYet =>
      'Aucun réglage cloud synchronisé pour l\'instant - les modifications seront envoyées au fil de votre utilisation de Forja';

  @override
  String profileSyncSections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections de réglages synchronisées avec ce profil',
      one: '$count section de réglages synchronisée avec ce profil',
    );
    return '$_temp0';
  }

  @override
  String get profileCloudSyncLabel => 'Synchronisation cloud';

  @override
  String get profileSignedInWaitingSync =>
      'Connecté · en attente de synchronisation';

  @override
  String get profileSynced => 'Synchronisé';

  @override
  String get profileAccountActiveHint => 'Compte cloud Forja actif';

  @override
  String get profileAccountSwitchHint =>
      'Appuyez pour changer de compte ou en ajouter';

  @override
  String get profileWatchingNow => 'En cours de visionnage';

  @override
  String get profileActiveHint => 'Profil actif sur cet appareil';

  @override
  String get profileSwitchHint => 'Appuyez pour changer qui regarde';

  @override
  String get profileSignIn => 'Se connecter';

  @override
  String get profileNewHere => 'Nouveau ici ?';

  @override
  String get profileCreateAccountWeb => 'Créer un compte sur le web';

  @override
  String get profileOpensPortal =>
      'Ouvre le portail Forja dans votre navigateur';

  @override
  String get profileLinkIntroTv =>
      'Liez votre compte Forja avec un code ou un QR sur le portail. Vous pouvez continuer à utiliser Forja sans compte.';

  @override
  String get profileLinkWithCodeOrQr => 'Lier avec un code ou un QR';

  @override
  String get profileCreateAccountTvHint =>
      'Depuis un téléphone ou un ordinateur - puis liez cette TV';

  @override
  String get profileSignInIntro =>
      'Connectez-vous pour synchroniser profils et réglages entre vos appareils. Vous pouvez continuer à utiliser Forja sans compte.';

  @override
  String get profileSignInQuick =>
      'Connectez-vous avec votre téléphone ou votre ordinateur en moins d\'une minute.';

  @override
  String get profileEmailLabel => 'E-mail';

  @override
  String get profilePasswordLabel => 'Mot de passe';

  @override
  String get profileSigningIn => 'Connexion…';

  @override
  String get profileCancelWebLogin => 'Annuler la connexion web';

  @override
  String get profileWebLogin => 'Connexion web';

  @override
  String get downloadsChooseFolder => 'Choisir le dossier de téléchargement';

  @override
  String get downloadsFolderNotWritable =>
      'Impossible d\'écrire dans ce dossier';

  @override
  String get downloadsFolderChanged =>
      'Les nouveaux téléchargements seront enregistrés ici';

  @override
  String get downloadsFolderReset =>
      'Utilisation du dossier de téléchargement par défaut';

  @override
  String get downloadsDeleteAllCompletedTitle =>
      'Supprimer tous les téléchargements terminés ?';

  @override
  String get downloadsDeleteAllCompletedBody =>
      'Supprime tous les téléchargements terminés de cet appareil et libère l\'espace disque.';

  @override
  String get downloadsDeleteAll => 'Tout supprimer';

  @override
  String get downloadsCompletedDeleted => 'Téléchargements terminés supprimés';

  @override
  String downloadsTabActive(int count) {
    return 'Actifs ($count)';
  }

  @override
  String downloadsTabCompleted(int count) {
    return 'Terminés ($count)';
  }

  @override
  String get downloadsActiveEmptyTitle => 'Aucun téléchargement actif';

  @override
  String get downloadsActiveEmptyHint =>
      'Lancez-en un depuis la fiche, les Sources ou le lecteur.';

  @override
  String get downloadsCompletedEmptyTitle => 'Aucun téléchargement hors ligne';

  @override
  String get downloadsCompletedEmptyHint =>
      'Les titres terminés apparaissent ici — à regarder à tout moment, sans réseau.';

  @override
  String get downloadsStorageTitle => 'Stockage';

  @override
  String get downloadsStorageSubtitle =>
      'Bibliothèque hors ligne de ce profil.';

  @override
  String get downloadsRefresh => 'Actualiser';

  @override
  String get downloadsUsedOf => ' utilisés sur ';

  @override
  String downloadsFreeSuffix(String free) {
    return '  ·  $free libres';
  }

  @override
  String get downloadsLegendOffline => 'Hors ligne';

  @override
  String get downloadsLegendOther => 'Autre';

  @override
  String get downloadsLegendAvailable => 'Disponible';

  @override
  String get downloadsChange => 'Modifier';

  @override
  String get downloadsDefault => 'Par défaut';

  @override
  String get downloadsStatusQueued => 'En attente';

  @override
  String get downloadsStatusPaused => 'En pause';

  @override
  String get downloadsStatusFailed => 'Échec';

  @override
  String downloadsEta(String eta) {
    return 'Fin dans $eta';
  }

  @override
  String get downloadsPause => 'Pause';

  @override
  String get downloadsResume => 'Reprendre';

  @override
  String get downloadsRetry => 'Réessayer';

  @override
  String get downloadsCancel => 'Annuler';

  @override
  String get downloadsPlayOffline => 'Lire hors ligne';

  @override
  String get downloadsDelete => 'Supprimer';

  @override
  String get downloadsDeleteOneTitle => 'Supprimer le téléchargement ?';

  @override
  String downloadsDeleteOneBody(String title) {
    return 'Supprime « $title » de cet appareil.';
  }

  @override
  String get settingsUiAuto => 'Auto';

  @override
  String get settingsUiCancel => 'Annuler';

  @override
  String get settingsUiClose => 'Fermer';

  @override
  String get settingsUiLanP2pPairTitle => 'Associer un ordinateur';

  @override
  String get settingsUiLanP2pOfflineTitle => 'Ordinateur hors ligne';

  @override
  String get settingsUiLanP2pPairBody =>
      'Les torrents et autres flux P2P sont lus sur un serveur Forja de bureau, pas sur cette TV. Les flux HTTP directs restent lisibles ici. Associez-le une fois dans Paramètres → LAN.';

  @override
  String get settingsUiLanP2pOfflineBody =>
      'Les torrents et autres flux P2P nécessitent votre serveur Forja de bureau associé, sur le même Wi-Fi. Les flux HTTP directs restent lisibles sur cette TV.';

  @override
  String get settingsUiLanP2pOpenLan => 'Ouvrir LAN';

  @override
  String get settingsUiP2pAckTitle => 'Streaming P2P';

  @override
  String get settingsUiP2pAckAware => 'J\'en suis conscient';

  @override
  String get settingsUiP2pAckIntro =>
      'Ce flux utilise la technologie pair-à-pair (P2P). En continuant, vous confirmez être conscient que :';

  @override
  String get settingsUiP2pAckBulletIp =>
      'Votre adresse IP sera visible par les autres pairs du réseau';

  @override
  String get settingsUiP2pAckBulletResponsible =>
      'Vous êtes seul responsable du contenu auquel vous accédez';

  @override
  String get settingsUiP2pAckBulletLegalRight =>
      'Vous confirmez avoir le droit légal de diffuser ce contenu dans votre juridiction';

  @override
  String get settingsUiP2pAckBulletNoHosting =>
      'Forja n\'héberge, ne distribue et ne contrôle aucun contenu P2P';

  @override
  String get settingsUiP2pAckBulletNoLiability =>
      'Forja n\'assume aucune responsabilité pour les conséquences juridiques découlant de votre utilisation du streaming P2P';

  @override
  String get settingsUiP2pAckOutro =>
      'Vous utilisez cette fonctionnalité entièrement à vos propres risques. Torrent direct, Stremio et Nuvio peuvent être désactivés à tout moment dans les Paramètres.';

  @override
  String get settingsUiP2pAckVpnBanner =>
      'Pour une meilleure confidentialité, utilisez un VPN. Votre adresse IP est visible par les autres pairs.';

  @override
  String get settingsUiMadeWith => 'Fait avec ';

  @override
  String get settingsUiMadeWithBy => ' par ';

  @override
  String get playerScreenTryingNextStream => 'Essai du flux suivant…';

  @override
  String get playerScreenFindingAnotherStream => 'Recherche d\'un autre flux…';

  @override
  String get playerScreenFindingServers => 'Recherche de serveurs…';

  @override
  String get playerScreenFailedToStream => 'Échec de la lecture du flux';

  @override
  String get playerScreenExoSeparateAudioUnsupported =>
      'Piste audio séparée non prise en charge dans ExoPlayer - utilisez MediaKit dans les Paramètres.';

  @override
  String get playerScreenReconnecting => 'Reconnexion…';

  @override
  String get playerScreenReconnectFailed => 'Échec de la reconnexion';

  @override
  String playerScreenEpisodeNumber(String number) {
    return 'Épisode $number';
  }

  @override
  String get playerScreenPreviousEpisodeButton => 'Épisode précédent';

  @override
  String get playerScreenNextEpisodeButton => 'Épisode suivant';

  @override
  String get playerScreenAudio => 'Audio';

  @override
  String get playerScreenQuality => 'Qualité';

  @override
  String get playerScreenLoadingSources => 'Chargement des sources…';

  @override
  String get playerScreenFailedToLoadSources =>
      'Échec du chargement des sources';

  @override
  String get playerScreenCheckingSources => 'Vérification des sources';

  @override
  String get playerScreenNoStreamsFound => 'Aucun flux trouvé';

  @override
  String get playerScreenStream => 'Flux';

  @override
  String get playerScreenStremioStream => 'Flux Stremio';

  @override
  String get playerScreenFailedToResolveStream =>
      'Impossible de résoudre le flux';

  @override
  String get playerScreenTorrentStreamFailedToStart =>
      'Le flux torrent n\'a pas pu démarrer';

  @override
  String get playerScreenOpeningStream => 'Ouverture du flux…';

  @override
  String get playerScreenSources => 'Sources';

  @override
  String get playerScreenSubtitle => 'Sous-titre';

  @override
  String get playerScreenSubtitleFailed => 'Échec du sous-titre';

  @override
  String get playerScreenBack10s => 'Reculer de 10 s';

  @override
  String get playerScreenForward10s => 'Avancer de 10 s';

  @override
  String get playerScreenNoMoreEpisodes => 'Plus d\'épisodes';

  @override
  String get playerScreenCouldNotFindStreamForEpisode =>
      'Impossible de trouver un flux pour cet épisode';

  @override
  String get playerScreenLoadingEpisodeInfo =>
      'Chargement des infos de l\'épisode…';

  @override
  String playerScreenSeasonEpisode(int season, int episode) {
    return 'Saison $season · Épisode $episode';
  }

  @override
  String get playerScreenCheckingSourcesProgress => 'Vérification des sources…';

  @override
  String get playerScreenResolvingTorrent => 'Résolution du torrent…';

  @override
  String get playerScreenCheckingStremio => 'Vérification de Stremio…';

  @override
  String get playerScreenAutoSelection => 'Sélection auto';

  @override
  String get playerScreenAutoSelectionSubtitle =>
      'Serveurs, pistes, passer l\'intro';

  @override
  String get playerScreenAutoServer => 'Serveur auto';

  @override
  String get playerScreenAutoSource => 'Source auto';

  @override
  String get playerScreenAutoAudio => 'Audio auto';

  @override
  String get playerScreenAutoSubtitles => 'Sous-titres auto';

  @override
  String get playerScreenAutoSkipIntro => 'Passer l\'intro auto';

  @override
  String get playerScreenAutoNextEpisode => 'Épisode suivant auto';

  @override
  String get playerScreenVideoDecode => 'Décodage vidéo';

  @override
  String get playerScreenHwDecGpuSafe =>
      'Décodage matériel : activé (GPU, sûr)';

  @override
  String get playerScreenHwDecCopyBack => 'Décodage matériel : activé (copie)';

  @override
  String get playerScreenHwDecOffCpu => 'Décodage matériel : désactivé (CPU)';

  @override
  String get playerScreenSwDecodeSoftDisplay =>
      'Décodage logiciel + affichage logiciel (CPU)';

  @override
  String get playerScreenPlaybackSpeed => 'Vitesse de lecture';

  @override
  String get playerScreenPlaybackSpeedSubtitle =>
      'Vitesse à laquelle la lecture avance';

  @override
  String get playerScreenSpeedNormal => 'Normale';

  @override
  String get playerScreenAspectRatio => 'Format d\'image';

  @override
  String get playerScreenAspectRatioSubtitle => 'Ajuster la vidéo au cadre';

  @override
  String get playerScreenFitFit => 'AJUSTER';

  @override
  String get playerScreenFitCrop => 'RECADRER';

  @override
  String get playerScreenFitFill => 'ÉTIRER';

  @override
  String get playerScreenLoop => 'Boucle';

  @override
  String get playerScreenLoopSubtitle => 'Répéter le titre en cours';

  @override
  String get playerScreenOn => 'Activé';

  @override
  String get playerScreenOff => 'Désactivé';

  @override
  String get playerScreenTorrentStats => 'Statistiques torrent';

  @override
  String get playerScreenTorrentStatsSubtitle =>
      'Afficher la superposition des transferts en direct';

  @override
  String get playerScreenSkipRecap => 'Passer le résumé';

  @override
  String get playerScreenSkipIntro => 'Passer l\'intro';

  @override
  String get playerScreenSkipCredits => 'Passer le générique';

  @override
  String get playerScreenSkipPreview => 'Passer l\'aperçu';

  @override
  String get playerScreenPlay => 'Lire';

  @override
  String get playerScreenEpisodes => 'Épisodes';

  @override
  String get playerScreenSubtitles => 'Sous-titres';

  @override
  String get playerScreenFullscreen => 'Plein écran';

  @override
  String get playerScreenStreamFailed => 'Échec du flux';

  @override
  String get playerScreenPlaybackFailedOpenSources =>
      'La lecture a échoué. Ouvrez Sources et choisissez un autre flux.';

  @override
  String get playerScreenNoWorkingStream =>
      'Aucun flux fonctionnel trouvé parmi les fournisseurs.';

  @override
  String get playerScreenTorrentStreamFailedToOpen =>
      'Le flux torrent n\'a pas pu s\'ouvrir.';

  @override
  String get playerScreenDownloadedFileCantPlay =>
      'Le fichier téléchargé ne peut pas être lu';

  @override
  String get playerScreenPlaybackFailed => 'Échec de la lecture.';

  @override
  String get playerScreenUnlock => 'Déverrouiller';

  @override
  String get playerScreenCouldNotOpenStream => 'Impossible d\'ouvrir le flux';

  @override
  String get playerScreenSwitchingToMediaKit => 'Passage à MediaKit…';

  @override
  String get playerScreenPressEscAgain =>
      'Appuyez de nouveau sur Échap pour quitter';

  @override
  String get playerScreenNextEpisodeTooltip => 'Épisode suivant';

  @override
  String get playerScreenPlayer => 'Lecteur';

  @override
  String playerScreenSourceFailed(String title) {
    return 'Échec : $title';
  }

  @override
  String get playerControlAirPlayEnded => 'AirPlay terminé';

  @override
  String get playerControlAirPlayOpenFailed => 'Impossible d\'ouvrir AirPlay';

  @override
  String get playerControlAirPlaySubtitlesUnavailable =>
      'Les sous-titres ne peuvent pas être lus sur AirPlay pour ce flux';

  @override
  String get playerControlAllProviders => 'Tous';

  @override
  String get playerControlAspectRatio => 'Format de l\'image';

  @override
  String get playerControlAspectRatioSubtitle =>
      'Comment la vidéo remplit l\'écran';

  @override
  String get playerControlAudio => 'Audio';

  @override
  String get playerControlAutoAudio => 'Audio auto';

  @override
  String get playerControlAutoNext => 'Suivant auto';

  @override
  String get playerControlAutoSelection => 'Sélection automatique';

  @override
  String get playerControlAutoSelectionSubtitle =>
      'Serveurs, pistes, passage de l\'intro';

  @override
  String get playerControlAutoServer => 'Serveur auto';

  @override
  String get playerControlAutoSource => 'Source auto';

  @override
  String get playerControlAutoSubtitles => 'Sous-titres auto';

  @override
  String get playerControlAvPlayerMacOnly => 'AVPlayer est réservé à macOS';

  @override
  String get playerControlBack => 'Retour';

  @override
  String get playerControlBack10s => 'Reculer de 10 s';

  @override
  String get playerControlBuffering => 'Mise en mémoire tampon';

  @override
  String get playerControlBufferingEllipsis => 'Mise en mémoire tampon…';

  @override
  String get playerControlBuiltIn => 'Intégré';

  @override
  String get playerControlCast => 'Diffuser';

  @override
  String playerControlCastStarting(String label) {
    return 'Démarrage de $label…';
  }

  @override
  String playerControlCastTargetUnavailable(String label) {
    return '$label n\'est pas encore disponible';
  }

  @override
  String get playerControlCastTo => 'Diffuser vers';

  @override
  String get playerControlCastUnsupported =>
      'La diffusion n\'est pas prise en charge sur cet appareil';

  @override
  String playerControlCastingTo(String label) {
    return 'Diffusion vers $label';
  }

  @override
  String get playerControlChangePlayer => 'Changer de lecteur';

  @override
  String get playerControlCheck => 'Vérifier';

  @override
  String playerControlCheckingOrdinal(int ordinal, int total) {
    return 'Vérification $ordinal/$total…';
  }

  @override
  String get playerControlCheckingServer => 'Vérification du serveur…';

  @override
  String get playerControlCheckingSources => 'Vérification des sources';

  @override
  String get playerControlCheckingStream => 'Vérification du flux…';

  @override
  String get playerControlChoosePlayer => 'Choisir un lecteur';

  @override
  String get playerControlCrop => 'Rogner';

  @override
  String get playerControlDetails => 'Détails';

  @override
  String get playerControlEngineDrmNeedsExo => 'Le DRM nécessite ExoPlayer';

  @override
  String get playerControlEngineSeparateAudioNeedsMediaKit =>
      'L\'audio séparé nécessite MediaKit';

  @override
  String get playerControlEngineTorrentNeedsMediaKit =>
      'Les flux torrent nécessitent MediaKit';

  @override
  String playerControlEpisodeNumber(int number) {
    return 'Épisode $number';
  }

  @override
  String get playerControlEpisodes => 'Épisodes';

  @override
  String get playerControlExpand => 'Agrandir';

  @override
  String get playerControlExternalApp => 'Application externe';

  @override
  String get playerControlFailedToStream => 'Échec de la lecture du flux';

  @override
  String get playerControlFile => 'Fichier';

  @override
  String get playerControlFill => 'Remplir';

  @override
  String get playerControlFit => 'Ajuster';

  @override
  String get playerControlForward10s => 'Avancer de 10 s';

  @override
  String get playerControlInAppMiniPlayer => 'Mini-lecteur intégré';

  @override
  String get playerControlInStream => 'Dans le flux';

  @override
  String get playerControlJackettNotConfigured =>
      'Jackett n\'est pas configuré';

  @override
  String get playerControlKeepsStreamAlive =>
      'Forja garde le flux actif pendant que vous regardez en externe.';

  @override
  String get playerControlLanguages => 'Langues';

  @override
  String playerControlLaunchFailed(String type) {
    return 'Échec du lancement ($type). Consultez la console pour plus de détails.';
  }

  @override
  String get playerControlMinimize => 'Réduire';

  @override
  String get playerControlMute => 'Couper le son';

  @override
  String get playerControlNext => 'Suivant';

  @override
  String get playerControlNextEpisode => 'Épisode suivant';

  @override
  String get playerControlNoAudioTracks => 'Aucune piste audio trouvée';

  @override
  String get playerControlNoEpisodesFound => 'Aucun épisode trouvé';

  @override
  String get playerControlNoExternalPlayers => 'Aucun lecteur externe installé';

  @override
  String playerControlNoFilterSources(String filter) {
    return 'Aucune source $filter';
  }

  @override
  String get playerControlNoForjaPlugins => 'Aucun plugin Forja installé';

  @override
  String get playerControlNoMatchingEpisodes => 'Aucun épisode correspondant';

  @override
  String get playerControlNoMatchingSources => 'Aucune source correspondante';

  @override
  String get playerControlNoMatchingStremioId =>
      'Aucun identifiant correspondant pour cet addon Stremio';

  @override
  String get playerControlNoNuvioScrapers =>
      'Aucun scraper Nuvio. Ajoutez-en dans Paramètres → Addons → Nuvio';

  @override
  String get playerControlNoOnlineSubtitles =>
      'Aucun sous-titre en ligne pour le moment. Touchez Rechercher pour saisir le nom du film ou de la série.';

  @override
  String get playerControlNoSavedFiles => 'Aucun fichier enregistré';

  @override
  String get playerControlNoServers => 'Aucun serveur';

  @override
  String get playerControlNoSourcesAvailable => 'Aucune source disponible';

  @override
  String get playerControlNoStreamToCast => 'Aucun flux à diffuser';

  @override
  String get playerControlNoStreamsAvailable => 'Aucun flux disponible';

  @override
  String get playerControlNoStreamsForjaPlugins =>
      'Aucun flux trouvé auprès des plugins Forja sélectionnés';

  @override
  String playerControlNoStreamsInAddon(String addon) {
    return 'Aucun flux trouvé dans $addon';
  }

  @override
  String get playerControlNoStreamsNuvio =>
      'Aucun flux trouvé auprès des fournisseurs Nuvio sélectionnés';

  @override
  String get playerControlNoStremioAddons =>
      'Aucun addon de flux Stremio. Ajoutez-en dans Paramètres → Addons → Stremio';

  @override
  String get playerControlNoSubtitles => 'Aucun sous-titre';

  @override
  String get playerControlNoTmdbIdForNuvio =>
      'Aucun identifiant TMDB pour les flux Nuvio';

  @override
  String get playerControlNoTorrentFiles =>
      'Aucun fichier trouvé dans ce torrent.';

  @override
  String get playerControlNoTorrentsFound => 'Aucun torrent trouvé';

  @override
  String get playerControlNoTracks => 'Aucune piste';

  @override
  String get playerControlNoneAvailable => 'Aucun disponible';

  @override
  String get playerControlNormal => 'Normale';

  @override
  String get playerControlOff => 'Désactivé';

  @override
  String get playerControlOn => 'Activé';

  @override
  String playerControlOpeningInPlayer(String player) {
    return 'Ouverture dans $player…';
  }

  @override
  String get playerControlParentalAlcoholDrugs => 'Alcool/Drogues';

  @override
  String get playerControlParentalFrightening => 'Effrayant';

  @override
  String get playerControlParentalNudity => 'Nudité';

  @override
  String get playerControlParentalProfanity => 'Grossièretés';

  @override
  String get playerControlParentalViolence => 'Violence';

  @override
  String get playerControlPause => 'Pause';

  @override
  String get playerControlPictureInPicture => 'Image dans l\'image';

  @override
  String get playerControlPlay => 'Lecture';

  @override
  String get playerControlPlaybackSpeed => 'Vitesse de lecture';

  @override
  String get playerControlPlayer => 'Lecteur';

  @override
  String playerControlPlayerCouldNotLaunch(String player) {
    return '$player n\'a pas pu être lancé. Est-il installé ?';
  }

  @override
  String playerControlPlayerNotFound(String player) {
    return '$player introuvable. Utilisation du lecteur intégré.';
  }

  @override
  String get playerControlPlayingInPip => 'Lecture en incrustation';

  @override
  String get playerControlPlayingNow => 'Lecture en cours';

  @override
  String get playerControlPlayingOnAirPlay => 'Lecture sur AirPlay';

  @override
  String get playerControlPreparingStream => 'Préparation du flux…';

  @override
  String get playerControlPressBackAgainToExit =>
      'Appuyez de nouveau sur Retour pour quitter';

  @override
  String get playerControlPressBackToLeave => 'Appuyez sur Retour pour quitter';

  @override
  String get playerControlPressEscAgainToExit =>
      'Appuyez de nouveau sur Échap pour quitter';

  @override
  String get playerControlPrevious => 'Précédent';

  @override
  String get playerControlPreviousEpisode => 'Épisode précédent';

  @override
  String playerControlProviderUnavailable(String name) {
    return '$name est indisponible';
  }

  @override
  String get playerControlProwlarrNotConfigured =>
      'Prowlarr n\'est pas configuré';

  @override
  String get playerControlQuality => 'Qualité';

  @override
  String get playerControlQualityNotAvailable =>
      'Qualité pas encore disponible';

  @override
  String playerControlRelaunchInPlayer(String player) {
    return 'Relancer dans $player';
  }

  @override
  String get playerControlSearch => 'Rechercher';

  @override
  String playerControlSearchingHint(String hint) {
    return 'Recherche : $hint';
  }

  @override
  String get playerControlSearchingSubtitles => 'Recherche de sous-titres…';

  @override
  String playerControlSeasonNumber(int number) {
    return 'Saison $number';
  }

  @override
  String get playerControlSelectProvider =>
      'Sélectionnez au moins un fournisseur';

  @override
  String get playerControlSelectServer => 'Sélectionnez un serveur';

  @override
  String get playerControlServers => 'Serveurs';

  @override
  String get playerControlShuffle => 'Aléatoire';

  @override
  String get playerControlSource => 'Source';

  @override
  String playerControlSourceTip(String label) {
    return 'Source : $label';
  }

  @override
  String playerControlSourceTipWithServer(String label, String server) {
    return 'Source : $label · $server';
  }

  @override
  String playerControlSourcesTip(String label) {
    return 'Sources : $label';
  }

  @override
  String playerControlSourcesTipWithServer(String label, String server) {
    return 'Sources : $label · $server';
  }

  @override
  String get playerControlStatusChecking => 'Vérification…';

  @override
  String get playerControlStatusPlaying => 'En lecture';

  @override
  String get playerControlStatusUnavailable => 'Indisponible';

  @override
  String get playerControlStream => 'Flux';

  @override
  String get playerControlStreamActive => 'Flux actif';

  @override
  String playerControlStreamCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flux',
      one: '$count flux',
    );
    return '$_temp0';
  }

  @override
  String playerControlStreamNumber(int number) {
    return 'Flux $number';
  }

  @override
  String get playerControlStreams => 'Flux';

  @override
  String playerControlStreamsServer(String server) {
    return 'Flux · $server';
  }

  @override
  String get playerControlSubBgOpacity => 'Opacité du fond';

  @override
  String get playerControlSubBold => 'Gras';

  @override
  String get playerControlSubDecreaseDelay => 'Diminuer le décalage';

  @override
  String get playerControlSubDelay => 'Décalage';

  @override
  String get playerControlSubFont => 'Police';

  @override
  String get playerControlSubIncreaseDelay => 'Augmenter le décalage';

  @override
  String get playerControlSubPosition => 'Position';

  @override
  String get playerControlSubSize => 'Taille';

  @override
  String get playerControlSubTextColor => 'Couleur du texte';

  @override
  String get playerControlSubtitleSettings => 'Paramètres des sous-titres';

  @override
  String get playerControlSubtitleSettingsTitle => 'Paramètres des sous-titres';

  @override
  String get playerControlSubtitles => 'Sous-titres';

  @override
  String get playerControlSwitchingPlayer => 'Changement de lecteur…';

  @override
  String get playerControlTapServerToCheck =>
      'Touchez le serveur pour le vérifier';

  @override
  String playerControlTipOffline(String base) {
    return '$base · Hors ligne';
  }

  @override
  String playerControlTorrentEta(String eta) {
    return 'Restant $eta';
  }

  @override
  String get playerControlTorrentFiles => 'Fichiers du torrent';

  @override
  String playerControlTorrentPeers(int active, int total) {
    return '$active actifs · $total vus';
  }

  @override
  String playerControlTorrentSeeders(String seeders) {
    return '$seeders seeders';
  }

  @override
  String get playerControlTracks => 'Pistes';

  @override
  String playerControlTracksGroup(String group) {
    return 'Pistes · $group';
  }

  @override
  String playerControlTranslatedFrom(String source) {
    return 'Traduit · $source';
  }

  @override
  String get playerControlUnknownStream => 'Flux inconnu';

  @override
  String get playerControlUnmute => 'Rétablir le son';

  @override
  String playerControlViaPlayer(String player) {
    return 'via $player';
  }

  @override
  String get playerControlVlcNotInstalled => 'VLC (libVLC) n\'est pas installé';

  @override
  String get playerControlWatchInForja => 'Regarder dans Forja à la place';

  @override
  String get playerControlWatchParty => 'Watch Party';

  @override
  String get playerControlWatchPartySoon => 'Watch Party - bientôt disponible';

  @override
  String get playerSourcePortalNotFound => 'Portail introuvable';

  @override
  String get playerSourceOpenStreamFailed => 'Impossible d\'ouvrir le flux';

  @override
  String get playerSourceNoEpisodeSelected => 'Aucun épisode sélectionné';

  @override
  String get playerSourceOpenEpisodeFailed => 'Impossible d\'ouvrir l\'épisode';

  @override
  String playerSourceVodEpisodeTitle(int number, String title) {
    return 'Ép. $number · $title';
  }

  @override
  String get playerSourceStreamsTitle => 'Flux';

  @override
  String get playerSourcePlaybackFailedTitle =>
      'Impossible de lancer la lecture';

  @override
  String get playerSourceResolvingLink =>
      'Résolution du lien de téléchargement…';

  @override
  String get playerSourceResolvingLinkHint =>
      'Récupération du lien magnet depuis la page du torrent.';

  @override
  String get playerSourceMagnetResolveFailed =>
      'Impossible de résoudre un lien magnet pour ce torrent.';

  @override
  String get playerSourceTorrentStartFailed =>
      'Le flux torrent n\'a pas pu démarrer.';

  @override
  String get playerSourceStreamStartFailed =>
      'Impossible de lancer ce flux. Réessayez ou choisissez une autre source.';

  @override
  String get playerSourceNoMatches => 'Aucun résultat';

  @override
  String get playerSourceNoChannelsMatch => 'Aucune chaîne ne correspond';

  @override
  String get playerSourceSearchChannelsHint => 'Rechercher des chaînes…';

  @override
  String get playerSourcePeers => 'pairs';

  @override
  String playerSourcePeersOf(int seen) {
    return 'sur $seen pairs';
  }

  @override
  String playerSourcePeersSeen(int seen) {
    return '$seen vus';
  }

  @override
  String get playerSourceStatDownload => 'Téléchargement';

  @override
  String get playerSourceStatFileCached => 'Fichier en cache';

  @override
  String get playerSourceFilterAll => 'Tout';

  @override
  String get playerSourceFilterAudio => 'Audio';

  @override
  String get playerSourceAvailableSources => 'Sources disponibles';

  @override
  String get playerSourceSortSeedersHigh => 'Seeders (décroissant)';

  @override
  String get playerSourceSortSeedersLow => 'Seeders (croissant)';

  @override
  String get playerSourceSortQualityHigh => 'Qualité (décroissante)';

  @override
  String get playerSourceSortQualityLow => 'Qualité (croissante)';

  @override
  String get playerSourceSortSizeHigh => 'Taille (décroissante)';

  @override
  String get playerSourceSortSizeLow => 'Taille (croissante)';

  @override
  String get playerSourceStoppedActiveDownload => 'Téléchargement actif arrêté';

  @override
  String get playerSourceDownloadsCleared => 'Téléchargements effacés';

  @override
  String get playerSourceStopClearFailed =>
      'Impossible d\'arrêter ou d\'effacer les téléchargements torrent';

  @override
  String get playerSourceStopAndClear => 'Arrêter et effacer';

  @override
  String get playerSourceSearchHint => 'Rechercher';

  @override
  String get playerSourceFiltersTitle => 'Filtres';

  @override
  String get playerSourceFilterCategory => 'Catégorie';

  @override
  String get playerSourceFilterSort => 'Trier';

  @override
  String get playerSourceFilterQuality => 'Qualité';

  @override
  String get playerSourceFilterSize => 'Taille';

  @override
  String get playerSourceFilterLanguage => 'Langue';

  @override
  String get playerSourceFilterTech => 'Technique';

  @override
  String get playerSourceFilterOnline => 'En ligne';

  @override
  String get playerSourcePlaying => 'En lecture';

  @override
  String get playerSourceCheckingSize => 'Vérification de la taille…';

  @override
  String get playerSourceSizeUnknown => 'Taille inconnue';

  @override
  String get playerSourceNotEnoughSpace => 'Espace libre insuffisant';

  @override
  String get playerSourceDownloadHeading => 'TÉLÉCHARGER';

  @override
  String get playerSourceDownloadOfflineHeading => 'TÉLÉCHARGER HORS LIGNE ?';

  @override
  String get playerSourceDownloadTooltip => 'Télécharger';

  @override
  String get playerSourcePlayOnline => 'Lire en ligne';

  @override
  String get playerSourceCopyMagnet => 'Copier le lien magnet';

  @override
  String get playerSourceMagnetCopied => 'Lien magnet copié';

  @override
  String get playerSourceSourcesTitle => 'Sources';

  @override
  String get playerSourceDownloadedChip => 'Téléchargés';

  @override
  String get playerTrailerLoadFailed =>
      'Impossible de charger cette bande-annonce';

  @override
  String get playerTrailerOpenInYouTube => 'Ouvrir dans YouTube';

  @override
  String get playerTrailerBack => 'Retour';

  @override
  String get playerTrailerMute => 'Couper le son';

  @override
  String get playerTrailerReplay => 'Revoir';

  @override
  String get playerTrailerPause => 'Pause';

  @override
  String get playerTrailerPlay => 'Lecture';

  @override
  String get playerTrailerBack10 => 'Reculer de 10 s';

  @override
  String get playerTrailerForward10 => 'Avancer de 10 s';

  @override
  String get playerTrailerSubtitles => 'Sous-titres';

  @override
  String get playerTrailerQuality => 'Qualité';

  @override
  String get playerTrailerPlaybackSpeed => 'Vitesse de lecture';

  @override
  String get playerTrailerFullscreen => 'Plein écran';

  @override
  String get playerTrailerLoading => 'Chargement…';

  @override
  String playerTrailerNextIn(int seconds) {
    return 'Bande-annonce suivante · $seconds s';
  }

  @override
  String get playerTrailerUpNext => 'À suivre';

  @override
  String get playerTrailerSubtitlesOff => 'Désactivés';

  @override
  String get playerTrailerNoSubtitles =>
      'Aucun sous-titre disponible pour cette bande-annonce.';

  @override
  String playerTrailerCaptionAuto(String name) {
    return '$name (auto)';
  }

  @override
  String get playerTrailerNoQuality =>
      'Aucune option de qualité pour cette bande-annonce.';

  @override
  String get playerTrailerPlayerMenuTitle => 'Lecteur';

  @override
  String get playerTrailerBuiltIn => 'Intégré';

  @override
  String get playerTrailerForjaTrailer => 'Bande-annonce Forja';

  @override
  String get playerTrailerExternalApp => 'Application externe';

  @override
  String get playerTrailerOpenYouTubeFailed => 'Impossible d\'ouvrir YouTube';

  @override
  String get playerLiveStreamEnded => 'Flux terminé';

  @override
  String get playerLiveReconnecting => 'Reconnexion…';

  @override
  String get playerLivePreparingPlayback => 'Préparation de la lecture…';

  @override
  String get playerLiveRefreshingStream => 'Actualisation du flux…';

  @override
  String get playerLiveUnlockingSource => 'Déverrouillage de la source…';

  @override
  String get playerLiveStreamOffline => 'Flux hors ligne';

  @override
  String get playerLivePlaybackFailed => 'Échec de la lecture';

  @override
  String get playerLiveSwitchingPlayer => 'Changement de lecteur…';

  @override
  String get playerLiveSwitchingSoftwareDecode =>
      'Passage au décodage logiciel…';

  @override
  String get playerLiveBuffering => 'Mise en mémoire tampon…';

  @override
  String playerLiveSwitchingTo(String name) {
    return 'Passage à $name…';
  }

  @override
  String playerLiveTrying(String name) {
    return 'Essai de $name…';
  }

  @override
  String playerLiveOfflineRetrying(int seconds) {
    return 'Flux hors ligne - nouvelle tentative toutes les $seconds s…';
  }

  @override
  String playerLiveReconnectingAttempt(int attempt, int max) {
    return 'Reconnexion… (tentative $attempt/$max)';
  }

  @override
  String get playerLiveSubtitleFailed => 'Échec du sous-titre';

  @override
  String get playerLiveSearchSubtitles => 'Rechercher des sous-titres';

  @override
  String get playerLiveFilmOrSeriesName => 'Nom du film ou de la série';

  @override
  String get playerLiveYearOptional => 'Année (facultatif)';

  @override
  String get playerLiveSeasonLabel => 'Saison';

  @override
  String get playerLiveEpisodeLabel => 'Épisode';

  @override
  String playerLiveExternalPlayerNotFound(String player) {
    return '$player est introuvable.';
  }

  @override
  String get playerLiveStreamStats => 'Stats du flux';

  @override
  String get playerLiveInAppMiniPlayer => 'Mini-lecteur intégré';

  @override
  String get playerLivePictureInPicture => 'Image dans l\'image';

  @override
  String get playerLiveBadge => 'EN DIRECT';

  @override
  String playerLiveEpisodeFallback(int number) {
    return 'Épisode $number';
  }

  @override
  String playerLiveSeasonTitle(int number) {
    return 'Saison $number';
  }

  @override
  String playerLiveShowSeasonTitle(String show, int number) {
    return '$show · Saison $number';
  }

  @override
  String get playerLiveSourceTitle => 'Source';

  @override
  String get playerLiveVlcNotFound =>
      'VLC est introuvable. Installez VLC ou utilisez MediaKit.';

  @override
  String get playerLiveStatsStatus => 'État';

  @override
  String get playerLiveStatsBuffering => 'Mise en mémoire tampon';

  @override
  String get playerLiveStatsPaused => 'En pause';

  @override
  String get playerLiveStatsEngine => 'Moteur';

  @override
  String get playerLiveStatsRecoveries => 'Reprises';

  @override
  String get playerLiveStatsResolution => 'Résolution';

  @override
  String get playerLiveStatsVideo => 'Vidéo';

  @override
  String get playerLiveStatsVideoBitrate => 'Débit vidéo';

  @override
  String get playerLiveStatsDisplayFps => 'FPS d\'affichage';

  @override
  String get playerLiveStatsAudioTrack => 'Piste audio';

  @override
  String get playerLiveStatsAudioBitrate => 'Débit audio';

  @override
  String get playerLiveStatsSubtitle => 'Sous-titre';

  @override
  String get playerLiveStatsOff => 'Désactivé';

  @override
  String get playerLiveStatsCache => 'Cache';

  @override
  String get playerLiveStatsCacheUsed => 'Cache utilisé';

  @override
  String get playerLiveStatsBufferedAhead => 'Tampon d\'avance';

  @override
  String get playerLiveStatsVolume => 'Volume';

  @override
  String get playerLiveStatsSpeed => 'Vitesse';

  @override
  String get playerLiveStatsDroppedFrames => 'Images perdues';

  @override
  String get playerLiveStatsDecoderDrops => 'Pertes du décodeur';

  @override
  String get playerLiveStatsVideoTrack => 'Piste vidéo';

  @override
  String get playerLiveStatsRetries => 'Tentatives';

  @override
  String get playerLiveStatsYes => 'oui';

  @override
  String get playerLiveStatsNo => 'non';

  @override
  String get playerLivePlayingOnAirPlay => 'Lecture sur AirPlay';

  @override
  String get playerLiveCast => 'Diffuser';

  @override
  String get engineModelsHubs => 'Hubs';

  @override
  String get engineModelsLive => 'Live';

  @override
  String get engineModelsMovie => 'Film';

  @override
  String get engineModelsMovieAndTv => 'Film et TV';

  @override
  String get engineModelsPlugins => 'Plugins';

  @override
  String get engineModelsLanguageItalian => 'Italien';

  @override
  String get engineModelsLanguageGerman => 'Allemand';

  @override
  String get engineModelsLanguagePortuguese => 'Portugais';

  @override
  String get engineModelsLanguageArabic => 'Arabe';

  @override
  String get engineModelsLanguageHindi => 'Hindi';

  @override
  String get engineModelsLanguageTurkish => 'Turc';

  @override
  String get engineModelsLanguageJapanese => 'Japonais';

  @override
  String get engineModelsLanguageKorean => 'Coréen';

  @override
  String get engineModelsLanguageChinese => 'Chinois';

  @override
  String get engineModelsLanguageDutch => 'Néerlandais';

  @override
  String get engineModelsLanguagePolish => 'Polonais';

  @override
  String get engineModelsLanguageRussian => 'Russe';

  @override
  String get engineRuntimeActionFailed => 'Échec de l\'action';

  @override
  String get engineRuntimeAddToMyList => 'Ajouter à Ma liste';

  @override
  String get engineRuntimeAddedToMyList => 'Ajouté à Ma liste';

  @override
  String engineRuntimeAllKind(String kind) {
    return 'Tout $kind';
  }

  @override
  String get engineRuntimeCast => 'Distribution';

  @override
  String engineRuntimeClearKind(String kind) {
    return 'Effacer $kind';
  }

  @override
  String get engineRuntimeContinueWatching => 'Continuer à regarder';

  @override
  String engineRuntimeCreditsShort(int credits) {
    return '$credits cr';
  }

  @override
  String get engineRuntimeDealDisabled =>
      'Deal n\'est pas activé sur ce compte';

  @override
  String engineRuntimeDealDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portails distribués',
      one: '$count portail distribué',
    );
    return '$_temp0';
  }

  @override
  String get engineRuntimeDealNone =>
      'Aucun portail distribué — le pool est peut-être vide';

  @override
  String engineRuntimeDealRefreshFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count portails distribués, mais la liste n\'a pas pu s\'actualiser — rouvrez Portails',
      one:
          '$count portail distribué, mais la liste n\'a pas pu s\'actualiser — rouvrez Portails',
    );
    return '$_temp0';
  }

  @override
  String get engineRuntimeDealSignIn =>
      'Connectez-vous et choisissez un profil pour utiliser Deal';

  @override
  String engineRuntimeDealTooltipCredits(String label, int credits) {
    return '$label ($credits crédits)';
  }

  @override
  String engineRuntimeDealTooltipNoCredits(String label) {
    return '$label (aucun crédit)';
  }

  @override
  String get engineRuntimeDetails => 'Détails';

  @override
  String get engineRuntimeFetchingCatalog => 'Récupération du catalogue…';

  @override
  String get engineRuntimeFilms => 'Films';

  @override
  String get engineRuntimeFilters => 'Filtres';

  @override
  String get engineRuntimeHome => 'Accueil';

  @override
  String get engineRuntimeHubLayoutInvalid =>
      'La mise en page de ce hub n\'est pas valide.';

  @override
  String get engineRuntimeHubLoadFailed =>
      'Impossible de charger ce hub. Réessayez.';

  @override
  String get engineRuntimeHubPluginOff =>
      'Ce plugin de hub est désactivé. Activez-le dans Paramètres → Sources → Forja (Hubs).';

  @override
  String get engineRuntimeListEmpty => 'Votre liste est vide';

  @override
  String get engineRuntimeLoading => 'Chargement…';

  @override
  String get engineRuntimeMyList => 'Ma liste';

  @override
  String get engineRuntimeNoChannelsInView => 'Aucune chaîne dans cette vue';

  @override
  String get engineRuntimeNoFavorites => 'Aucun favori';

  @override
  String get engineRuntimeNoFavoritesHint =>
      'Ajoutez une chaîne en direct aux favoris pour la garder ici.';

  @override
  String get engineRuntimeNoHubPack => 'Aucun pack de hub pour cet onglet.';

  @override
  String get engineRuntimeNoPlayableStream => 'Aucun flux lisible';

  @override
  String get engineRuntimeNoResults => 'Aucun résultat';

  @override
  String get engineRuntimeNothingHere => 'Rien ici';

  @override
  String get engineRuntimeNothingHereYet => 'Rien ici pour l\'instant.';

  @override
  String get engineRuntimeNothingWatched => 'Rien de regardé pour l\'instant';

  @override
  String get engineRuntimeNothingWatchedHint =>
      'Les chaînes lues dans Live apparaissent ici (30 dernières).';

  @override
  String get engineRuntimeOpen => 'Ouvrir';

  @override
  String get engineRuntimeOptions => 'Options';

  @override
  String get engineRuntimePlay => 'Lire';

  @override
  String get engineRuntimePortalNotFound => 'Portail introuvable';

  @override
  String get engineRuntimePortalSelectFailed =>
      'Impossible de sélectionner le portail';

  @override
  String get engineRuntimePortals => 'Portails';

  @override
  String get engineRuntimePortalsNoPack => 'Aucun pack de portails installé';

  @override
  String get engineRuntimePortalsUnavailable => 'Portails indisponibles';

  @override
  String get engineRuntimeRecommendations => 'Recommandations';

  @override
  String get engineRuntimeRemoveFromMyList => 'Retirer de Ma liste';

  @override
  String get engineRuntimeRemoved => 'Supprimé';

  @override
  String get engineRuntimeRemovedFromMyList => 'Retiré de Ma liste';

  @override
  String get engineRuntimeRemovedLocallySimklFailed =>
      'Retiré en local · échec Simkl';

  @override
  String engineRuntimeResumeFailed(String error) {
    return 'Échec de la reprise : $error';
  }

  @override
  String get engineRuntimeSavedLocallySimklFailed =>
      'Enregistré en local · échec Simkl';

  @override
  String get engineRuntimeSchedule => 'Programme';

  @override
  String get engineRuntimeScheduleAiring => 'En cours';

  @override
  String get engineRuntimeScheduleAiringHint =>
      'En cours et 24/7 — y compris les lignes sans flux pour l\'instant';

  @override
  String get engineRuntimeScheduleAiringUpcoming => 'En cours + à venir';

  @override
  String get engineRuntimeScheduleBothHint =>
      'En cours + 24/7, plus les événements à venir dans l\'horizon';

  @override
  String get engineRuntimeScheduleHorizon => 'Horizon';

  @override
  String engineRuntimeScheduleHorizonHint(int hours) {
    return 'Coups d\'envoi à venir dans les $hours h';
  }

  @override
  String get engineRuntimeScheduleIntro =>
      'Quoi afficher, et jusqu\'où charger les événements à venir :';

  @override
  String engineRuntimeScheduleNext(String horizon) {
    return 'Suivant · $horizon';
  }

  @override
  String get engineRuntimeScheduleStatus => 'Statut';

  @override
  String get engineRuntimeScheduleUpcoming => 'À venir';

  @override
  String get engineRuntimeScheduleUpcomingHint =>
      'Pas encore commencé, dans l\'horizon ci-dessous';

  @override
  String get engineRuntimeSearchFailed => 'Échec de la recherche';

  @override
  String get engineRuntimeSearchHint => 'Rechercher…';

  @override
  String get engineRuntimeSearchHintEnter =>
      'Appuyez sur Entrée pour rechercher';

  @override
  String get engineRuntimeSearchHintFilters =>
      'Réglez les filtres, puis touchez Rechercher';

  @override
  String get engineRuntimeSearchHintOk => 'Appuyez sur OK pour rechercher';

  @override
  String get engineRuntimeSearchPrompt => 'Recherchez votre contenu préféré';

  @override
  String get engineRuntimeSectionLoadFailed =>
      'Impossible de charger cette section.';

  @override
  String get engineRuntimeSeries => 'Séries';

  @override
  String get engineRuntimeShareCodeCopied => 'Code de partage copié';

  @override
  String get engineRuntimeShareCodeFailed =>
      'Impossible de créer le code de partage';

  @override
  String engineRuntimeSimklSavedAs(String saved, String requested) {
    return 'Simkl a enregistré $saved (et non $requested)';
  }

  @override
  String engineRuntimeSimklStillAiring(String status) {
    return 'Toujours en cours sur Simkl · conservé comme $status';
  }

  @override
  String get engineRuntimeSomethingWrong => 'Une erreur s\'est produite';

  @override
  String get engineRuntimeSort => 'Trier';

  @override
  String get engineRuntimeSortCategories => 'Catégories';

  @override
  String get engineRuntimeSortChannels => 'Chaînes';

  @override
  String get engineRuntimeSortNameAsc => 'Nom (A–Z)';

  @override
  String get engineRuntimeSortNameDesc => 'Nom (Z–A)';

  @override
  String get engineRuntimeSortPlaylistOrder => 'Ordre de la playlist';

  @override
  String get engineRuntimeStream => 'Flux';

  @override
  String get engineRuntimeTrailers => 'Bandes-annonces';

  @override
  String get engineRuntimeUpdating => 'Mise à jour';

  @override
  String get engineRuntimeViewDetails => 'Voir les détails';

  @override
  String enginePacksUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs de plugins mis à jour',
      one: '$count pack de plugins mis à jour',
    );
    return '$_temp0';
  }

  @override
  String enginePacksUpdateTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mettre à jour $count packs de plugins ?',
      one: 'Mettre à jour le pack de plugins ?',
    );
    return '$_temp0';
  }

  @override
  String enginePacksUpdateBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Téléchargez et installez les versions plus récentes de ces packs.',
      one: 'Téléchargez et installez la version plus récente de ce pack.',
    );
    return '$_temp0';
  }

  @override
  String get enginePacksUpdateButton => 'Mettre à jour';

  @override
  String get enginePacksKindProviders => 'Fournisseurs';

  @override
  String get enginePacksKindLive => 'En direct';

  @override
  String get enginePacksKindTorrent => 'Torrent';

  @override
  String get enginePacksKindHubs => 'Hubs';

  @override
  String get enginePortalsShareCodeInvalid => 'Code de partage invalide';

  @override
  String get enginePortalsShareCodeNotFound =>
      'Code de partage introuvable ou invalide';

  @override
  String get enginePortalsShareUnavailable =>
      'Service de partage temporairement indisponible. Réessayez plus tard.';

  @override
  String get enginePortalsShareLoadFailed =>
      'Impossible de charger le code de partage';

  @override
  String get enginePortalsErrM3uNameRequired =>
      'Nom du portail requis pour les playlists M3U';

  @override
  String get enginePortalsErrUrlRequired => 'URL requise';

  @override
  String get enginePortalsErrXtreamRequired =>
      'URL, nom d\'utilisateur et mot de passe requis';

  @override
  String get enginePortalsErrMacRequired =>
      'Adresse MAC (nom d\'utilisateur) requise';

  @override
  String get enginePortalsActionFailed => 'Échec de l\'action';

  @override
  String get enginePortalsDefaultName => 'Portail';

  @override
  String get enginePortalsAdded => 'Portail ajouté';

  @override
  String get enginePortalsSaving => 'Enregistrement…';

  @override
  String get enginePortalsAdding => 'Ajout du portail…';

  @override
  String get enginePortalsEditTitle => 'Modifier le portail';

  @override
  String get enginePortalsAddTitle => 'Ajouter un portail';

  @override
  String get enginePortalsNameLabel => 'Nom du portail';

  @override
  String get enginePortalsNameHint => 'Mon fournisseur';

  @override
  String get enginePortalsNameRandom => 'Nom aléatoire';

  @override
  String get enginePortalsAddAction => 'Ajouter';

  @override
  String get enginePortalsShareCodeTitle => 'Code de partage';

  @override
  String get enginePortalsNameRequiredLabel => 'Nom du portail (obligatoire)';

  @override
  String get enginePortalsPlaylistUrl => 'URL de la playlist';

  @override
  String get enginePortalsChooseFile => 'Choisir un fichier local';

  @override
  String get enginePortalsMacLabel => 'Adresse MAC';

  @override
  String get enginePortalsUsernameLabel => 'Nom d\'utilisateur';

  @override
  String get enginePortalsUsernameHint => 'nom d\'utilisateur';

  @override
  String get enginePortalsGenerateMac => 'Générer une adresse MAC';

  @override
  String get enginePortalsSerialLabel => 'Numéro de série (facultatif)';

  @override
  String get enginePortalsSerialHint => 'numéro de série de l\'appareil';

  @override
  String get enginePortalsPasswordHint => 'mot de passe';

  @override
  String get enginePortalsShowPassword => 'Afficher le mot de passe';

  @override
  String get enginePortalsHidePassword => 'Masquer le mot de passe';

  @override
  String get enginePortalsUserAgentLabel => 'User-Agent (facultatif)';

  @override
  String get enginePortalsHideManual => 'Masquer la saisie manuelle';

  @override
  String get enginePortalsEnterUrlManually => 'Saisir l\'URL manuellement';

  @override
  String get enginePortalsLoadingShareCode => 'Chargement du code de partage…';

  @override
  String get engineDetailsFallbackTitle => 'Détails';

  @override
  String get engineDetailsMatchLive => 'En direct';

  @override
  String engineDetailsMatchViewers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spectateurs',
      one: '$count spectateur',
    );
    return '$_temp0';
  }

  @override
  String get engineDetailsMatchingLiveTv => 'Correspondance avec Live TV…';

  @override
  String get engineDetailsFetchingStreams => 'Récupération des flux…';

  @override
  String get engineDetailsPlay => 'Lire';

  @override
  String get engineDetailsLoading => 'Chargement';

  @override
  String get engineDetailsClearTooltip =>
      'Effacer la progression et le cache des flux';

  @override
  String get engineDetailsTrailer => 'Bande-annonce';

  @override
  String get engineDetailsMore => 'Plus';

  @override
  String engineDetailsSimklRating(int rating) {
    return 'Note Simkl : $rating';
  }

  @override
  String get engineDetailsRateOnSimkl => 'Noter sur Simkl';

  @override
  String get engineDetailsSimklLoginFirst =>
      'Connectez-vous d’abord à Simkl dans les Paramètres';

  @override
  String get engineDetailsRate => 'Noter';

  @override
  String get engineDetailsLoadFailed =>
      'Impossible de charger les détails. Réessayez.';

  @override
  String get engineDetailsNoSavedFile => 'Aucun fichier enregistré';

  @override
  String engineDetailsResumeEpisode(int episode) {
    return 'Reprendre ép. $episode';
  }

  @override
  String engineDetailsPlayEpisode(int episode) {
    return 'Lire ép. $episode';
  }

  @override
  String get engineDetailsCast => 'Distribution';

  @override
  String get engineDetailsCharacters => 'Personnages';

  @override
  String get engineDetailsCrew => 'Équipe';

  @override
  String engineStoreNoSearch(String hub) {
    return '$hub n’a pas de recherche';
  }

  @override
  String get engineStoreTypeToSearch => 'Saisissez un titre à rechercher';

  @override
  String engineStoreNoMatches(String hub) {
    return 'Aucun résultat dans $hub';
  }

  @override
  String get engineStoreUntitled => 'Sans titre';

  @override
  String get engineStoreHubLabel => 'Hub';

  @override
  String engineStoreSearchHub(String name) {
    return 'Rechercher dans $name';
  }

  @override
  String engineStoreOpenInHub(String hub) {
    return 'Ouvrir dans $hub';
  }

  @override
  String get engineStoreSearchTitle => 'Rechercher un titre';

  @override
  String get engineStoreSearchTitleTv => 'Rechercher un titre — OK pour saisir';

  @override
  String get engineStoreBestMatch => 'Meilleur résultat';

  @override
  String get engineStoreRemovedFromList => 'Retiré de Ma liste';

  @override
  String get engineStoreRemovedLocalFailed => 'Retiré localement · échec Simkl';

  @override
  String get engineStoreSavedLocalFailed =>
      'Enregistré localement · échec Simkl';

  @override
  String get engineStoreNoHub => 'Aucun hub disponible pour ouvrir ce titre';

  @override
  String get engineStoreNoHandoff => 'Ce résultat n’a pas de lien d’ouverture';

  @override
  String engineStoreNoHandoffFor(String name) {
    return 'Pas de lien d’ouverture pour $name';
  }

  @override
  String get accountBack => 'Retour';

  @override
  String get accountChooserLoadFailed =>
      'Impossible de charger les comptes enregistrés.';

  @override
  String get accountChooserSwitchFailed =>
      'Impossible de changer de compte. Reconnectez-vous avec cet utilisateur.';

  @override
  String accountChooserMaxAccounts(int count) {
    return 'Maximum de $count comptes sur cet appareil.';
  }

  @override
  String get accountChooserAddFailed =>
      'Impossible d\'ajouter le compte. Réessayez.';

  @override
  String get accountChooserTitle => 'Comptes';

  @override
  String get accountChooserHeading => 'Qui est connecté ?';

  @override
  String get accountChooserSubtitle =>
      'Changez de compte sur cet appareil, ou ajoutez-en un avec un QR / code.';

  @override
  String get accountChooserActiveGroup => 'Actif';

  @override
  String get accountChooserActiveNow => 'Actif maintenant';

  @override
  String get accountChooserOtherGroup => 'Autres comptes';

  @override
  String get accountChooserAdd => 'Ajouter un compte';

  @override
  String get accountChooserRemoveQuestion => 'Retirer ce compte ?';

  @override
  String get accountChooserTapToSwitch => 'Appuyez pour changer';

  @override
  String get accountChooserRemoveTooltip => 'Retirer de cet appareil';

  @override
  String get accountEntryMfaRequired =>
      'Application d\'authentification requise. Terminez la MFA sur le portail web, puis utilisez la connexion web.';

  @override
  String get accountEntryMfaPrompt =>
      'Saisissez le code à 6 chiffres de votre application d\'authentification.';

  @override
  String get accountEntryMfaShortCode =>
      'Saisissez le code d\'authentification à 6 chiffres.';

  @override
  String get accountEntryMfaVerifyFailed =>
      'Impossible de vérifier le code. Réessayez.';

  @override
  String get accountEntryMissingCredentials =>
      'Saisissez votre e-mail et votre mot de passe.';

  @override
  String get accountEntryConfirmEmail =>
      'Consultez votre e-mail et ouvrez le lien de confirmation, puis revenez vous connecter.';

  @override
  String get accountEntryConnectFailed =>
      'Impossible de se connecter à Forja. Vérifiez votre connexion et réessayez.';

  @override
  String get accountEntryWebOpening =>
      'Ouverture du navigateur - connectez-vous sur le web, puis revenez ici. Appuyez sur Annuler si le navigateur ne s\'ouvre pas.';

  @override
  String get accountEntryWebIncomplete =>
      'La connexion web n\'a pas abouti. Réessayez.';

  @override
  String get accountEntrySignupOpenFailed =>
      'Impossible d\'ouvrir la page d\'inscription dans votre navigateur.';

  @override
  String get accountEntryTagline => 'LECTEUR CRÉATIF';

  @override
  String get accountEntryHeadline => 'Un lecteur.\nVos sources.\nChaque ';

  @override
  String get accountEntryWordStream => 'stream';

  @override
  String get accountEntryWordSync => 'synchro';

  @override
  String get accountEntryWordLive => 'direct';

  @override
  String get accountEntryWordPlay => 'lecture';

  @override
  String get accountEntryIntro =>
      'Connectez-vous pour synchroniser paramètres et profils sur tous vos écrans. Les nouveaux comptes se créent sur le web - pas dans l\'app.';

  @override
  String get accountEntryChipIptvGuides => 'Guides IPTV';

  @override
  String get accountEntryChipProfiles => 'Profils';

  @override
  String get accountEntryChipDeskTv => 'Bureau → TV';

  @override
  String get accountEntryWelcome => 'Bon retour';

  @override
  String get accountEntryMfaSubtitle =>
      'Saisissez le code de votre application d\'authentification pour terminer la connexion.';

  @override
  String get accountEntrySubtitle =>
      'Utilisez votre compte Forja, ou ouvrez le navigateur pour vous connecter sur le web.';

  @override
  String get accountEntryAuthCodeLabel => 'Code d\'authentification';

  @override
  String get accountEntryShowPassword => 'Afficher le mot de passe';

  @override
  String get accountEntryHidePassword => 'Masquer le mot de passe';

  @override
  String get accountEntryVerifying => 'Vérification…';

  @override
  String get accountEntryVerifyCode => 'Vérifier le code';

  @override
  String get accountEntryConnecting => 'Connexion…';

  @override
  String get accountEntryCreateOnWeb => 'Créer un compte sur le web →';

  @override
  String get accountEntryContinueNoAccount => 'Continuer sans compte';

  @override
  String get accountEntryGuestNote =>
      'Le mode invité garde tout sur cet appareil. Vous pourrez vous connecter plus tard depuis les Paramètres.';

  @override
  String get accountLinkExpired =>
      'Ce code a expiré. Recommencez pour en obtenir un nouveau.';

  @override
  String get accountLinkCancelled =>
      'La liaison a été annulée. Recommencez pour obtenir un nouveau code.';

  @override
  String get accountLinkSigningIn => 'Connexion en cours';

  @override
  String get accountLinkCreatingSession =>
      'Création d\'une session sécurisée pour cet appareil.';

  @override
  String get accountLinkThisDevice => 'LIER CET APPAREIL';

  @override
  String get accountLinkOpen => 'Ouvrez ';

  @override
  String get accountLinkEnterCode =>
      'Saisissez le code ou scannez le QR depuis votre téléphone.';

  @override
  String get accountGetNewCode => 'Obtenir un nouveau code';

  @override
  String get accountLinkThisTv => 'LIER CETTE TV';

  @override
  String get accountLinkOpenInBrowser =>
      'Ouvrir la page de liaison dans le navigateur';

  @override
  String get accountPacksUrlCopied =>
      'URL copiée — ouvrez-la sur votre téléphone';

  @override
  String get accountPacksOpenCommunityFailed =>
      'Impossible d\'ouvrir les packs de la communauté.';

  @override
  String get accountPacksLoadingOfficial => 'Chargement des packs officiels…';

  @override
  String get accountPacksLoadOfficialFailed =>
      'Impossible de charger les packs officiels. Passez cette étape et ajoutez-les plus tard dans les Paramètres.';

  @override
  String get accountPacksPreparing => 'Préparation des packs officiels…';

  @override
  String accountPacksInstalledWithErrors(int count, String details) {
    return 'Installé avec $count erreur(s) : $details';
  }

  @override
  String get accountPacksFinishing => 'Finalisation…';

  @override
  String get accountPacksInstallFailed =>
      'Échec de l\'installation. Vous pouvez passer cette étape et ajouter des packs plus tard dans les Paramètres.';

  @override
  String get accountPacksTitleChoose => 'Choisir les packs officiels';

  @override
  String get accountPacksTitleUnlock => 'Profitez de la meilleure expérience';

  @override
  String get accountPacksBodyPicking =>
      'Les packs recommandés sont cochés. Ajoutez-en ou retirez-en, puis appuyez sur Installer.';

  @override
  String get accountPacksBodyIntro =>
      'Les packs ajoutent des catalogues, des sources de streaming, du Live Sports, et plus encore. Choisissez des packs officiels ForjaHQ, ou parcourez les packs de la communauté et choisissez sur le web.';

  @override
  String get accountPacksLoading => 'Chargement…';

  @override
  String accountPacksTvCommunity(String url) {
    return 'Choisissez les packs sur votre téléphone\n$url';
  }

  @override
  String get accountPacksSkip => 'Passer pour l\'instant';

  @override
  String get accountProfileOpenFailed =>
      'Impossible d\'ouvrir ce profil. Vérifiez votre connexion et réessayez.';

  @override
  String get accountProfileMaxProfiles => 'Maximum de 5 profils par compte.';

  @override
  String get accountProfileSaveFailed => 'Impossible d\'enregistrer le profil.';

  @override
  String get accountProfileDeleteFailed => 'Impossible de supprimer le profil.';

  @override
  String get accountProfileLoadFailed =>
      'Impossible de charger les profils. Vérifiez votre connexion et réessayez.';

  @override
  String get accountProfileCreateTitle => 'Créez votre profil';

  @override
  String get accountProfileAdd => 'Ajouter un profil';

  @override
  String get accountProfileEditTitle => 'Modifier le profil';

  @override
  String get accountProfileAccountTag => 'COMPTE';

  @override
  String get accountProfileManage => 'Gérer les profils';

  @override
  String get accountProfileWhosWatching => 'Qui regarde ?';

  @override
  String get accountProfileLoadingProfiles => 'Chargement des profils…';

  @override
  String get accountProfileLoadWhosWatchingFailed =>
      'Impossible de charger les profils pour le moment.';

  @override
  String get accountProfileCreateHint =>
      'Créez un profil pour synchroniser les paramètres sur cet appareil.';

  @override
  String get accountProfileManageHint =>
      'Modifiez un profil ou ajoutez-en un nouveau.';

  @override
  String get accountProfileChooseHint =>
      'Choisissez le profil dont vous voulez les paramètres sur cet appareil.';

  @override
  String get accountProfileUseAnotherAccount => 'Utiliser un autre compte';

  @override
  String get accountProfileDone => 'Terminé';

  @override
  String get accountProfileAccountSettings => 'Paramètres du compte';

  @override
  String get accountProfileNewName => 'Nouveau profil';

  @override
  String get accountProfileNameLabel => 'Nom du profil';

  @override
  String get accountProfileChooseAvatar => 'CHOISIR UN AVATAR';

  @override
  String get accountProfileSaving => 'Enregistrement…';

  @override
  String get accountProfileSave => 'Enregistrer le profil';

  @override
  String get accountProfileDelete => 'Supprimer le profil';

  @override
  String get accountSplashLoadingProfile => 'Chargement du profil…';

  @override
  String get accountSplashSavingCurrent => 'Enregistrement du profil actuel…';

  @override
  String accountSplashLoadingNamed(String name) {
    return 'Chargement de $name…';
  }

  @override
  String get accountSplashSyncing => 'Synchronisation des paramètres…';

  @override
  String get accountSplashPulling => 'Récupération de vos onglets et sources…';

  @override
  String get accountSplashApplying => 'Application des préférences de lecture…';

  @override
  String get appBootAlmostReady => 'Presque prêt…';

  @override
  String get accountSplashWarmingHome => 'Préparation de l\'accueil…';

  @override
  String get accountSplashOpeningSyncing =>
      'Ouverture pendant la fin de la synchronisation des paramètres. Les portails IPTV se chargent dès qu\'ils sont prêts.';

  @override
  String get appBootPluginsBackground =>
      'Les plugins continuent de se télécharger en arrière-plan.';

  @override
  String get appBootOpeningLiveIptv => 'Ouverture de Live & IPTV…';

  @override
  String appBootOpeningNamed(String label) {
    return 'Ouverture de $label…';
  }

  @override
  String get appBootWarmingCatalog => 'Préparation du catalogue…';

  @override
  String get appBootLoadingPlugins => 'Chargement des plugins…';

  @override
  String get appBootJustAMoment => 'Un instant…';

  @override
  String get appBootStartingProxy => 'Démarrage du proxy de streaming…';

  @override
  String get appBootStartingTorrent => 'Démarrage du moteur torrent…';

  @override
  String get accountLinkSomethingWrong => 'Une erreur s\'est produite.';

  @override
  String get accountTvContinueGuest => 'Continuer en tant qu\'invité';

  @override
  String get accountTvTitle => 'Votre cinéma.\nSur grand écran.';

  @override
  String get accountTvBody =>
      'Le canapé est prêt. Forja aussi. Ouvrez un film, enchaînez une série, regardez le match ou zappez sur la TV en direct.';

  @override
  String get accountLinkCouldNot => 'LIAISON IMPOSSIBLE';

  @override
  String get syncPortalLimitUnlimited => 'Illimité';

  @override
  String get syncPortalLimitReached => 'Limite de portails atteinte.';

  @override
  String syncPortalLimitMax(int count) {
    return 'Maximum de $count portails par profil';
  }

  @override
  String get appBootGettingReady => 'Préparation en cours…';

  @override
  String get appBootSlowCatalog =>
      'Le chargement des services de catalogue prend plus de temps que prévu.';

  @override
  String get appBootWarmingShell => 'Préparation de l\'interface…';

  @override
  String get appBootLoadingProfile => 'Chargement de votre profil…';

  @override
  String get appBootCheckingConnection => 'Vérification de la connexion…';

  @override
  String get sharedDownloadsNoSavedFile => 'Aucun fichier enregistré';

  @override
  String get sharedDownloadsSaved => 'Enregistré';

  @override
  String sharedDownloadsSeasonNumber(int number) {
    return 'Saison $number';
  }

  @override
  String get sharedDownloadsDownloading => 'Téléchargement';

  @override
  String sharedDownloadsDownloadingCount(int count) {
    return 'Téléchargement · $count';
  }

  @override
  String sharedDownloadsSavedCount(int count) {
    return 'Enregistré · $count';
  }

  @override
  String get sharedDownloadsPlayOnline => 'Lire en ligne';

  @override
  String get sharedDownloadsView => 'Voir';

  @override
  String get sharedDownloadsExternalNoOffline =>
      'Les liens externes ne peuvent pas être enregistrés hors ligne';

  @override
  String get sharedDownloadsTorrentsNoOffline =>
      'Les torrents ne sont pas encore disponibles en téléchargement hors ligne';

  @override
  String get sharedDownloadsDashNoOffline =>
      'Les flux DASH ne peuvent pas encore être enregistrés hors ligne';

  @override
  String get sharedDownloadsStreamNoOffline =>
      'Ce flux ne peut pas être enregistré hors ligne';

  @override
  String sharedDownloadsFree(String size) {
    return '$size libres';
  }

  @override
  String get sharedDownloadsAlreadySaved => 'Déjà enregistré hors ligne';

  @override
  String sharedDownloadsAlreadyDownloading(String title) {
    return '$title est déjà en cours de téléchargement';
  }

  @override
  String sharedDownloadsDownloadingTitle(String title) {
    return 'Téléchargement de $title';
  }

  @override
  String get sharedDownloadsFailedToStart =>
      'Impossible de lancer le téléchargement';

  @override
  String get sharedDownloadsLinkExpired =>
      'Lien du flux expiré — ouvrez Sources et relancez le téléchargement';

  @override
  String get sharedDownloadsFileMissing =>
      'Le fichier téléchargé est introuvable';

  @override
  String get sharedDownloadsFileUnplayableDelete =>
      'Le fichier téléchargé est illisible — supprimez-le et téléchargez-le à nouveau';

  @override
  String get sharedDownloadsFileUnplayable =>
      'Le fichier téléchargé est illisible';

  @override
  String get sharedDownloadsNoOnlineStream => 'Aucun flux en ligne';

  @override
  String get sharedDownloadsFindingStream => 'Recherche d\'un flux…';

  @override
  String get sharedDownloadsSizeUnknown => 'Taille inconnue';

  @override
  String get sharedDownloadsFileMovedOrDeleted =>
      'Le fichier a été déplacé ou supprimé du disque';

  @override
  String get sharedDownloadsEmptyUrl => 'URL de téléchargement vide';

  @override
  String sharedDownloadsServerHttp(int code, String phrase) {
    return 'Le serveur a renvoyé HTTP $code : $phrase';
  }

  @override
  String get sharedDownloadsServerPlaylist =>
      'Le serveur a renvoyé une playlist ou une page, pas un fichier vidéo';

  @override
  String sharedDownloadsReconnectingRemaining(int attempt) {
    return 'Reconnexion pour les données restantes (tentative $attempt)...';
  }

  @override
  String sharedDownloadsReconnecting(int attempt) {
    return 'Reconnexion (tentative $attempt)...';
  }

  @override
  String get sharedDownloadsFileMissingShort =>
      'Fichier téléchargé introuvable';

  @override
  String get sharedDownloadsIncomplete =>
      'Téléchargement incomplet — supprimez-le et réessayez';

  @override
  String get sharedDownloadsNotPlayableVideo =>
      'Le fichier téléchargé n\'est pas une vidéo lisible';

  @override
  String get sharedDownloadsTooSmall =>
      'Téléchargement trop petit pour être un fichier vidéo';

  @override
  String sharedDownloadsSaveFinalFailed(String error) {
    return 'Échec de l\'enregistrement du fichier final : $error';
  }

  @override
  String sharedServicesUpdateReadyToInstall(String version) {
    return 'Forja $version est prêt à être installé.';
  }

  @override
  String get sharedServicesOpenDownloadUrl => 'Ouvrir l\'URL de téléchargement';

  @override
  String get sharedServicesUpdateFileGone =>
      'Le fichier de mise à jour téléchargé n\'est plus disponible.';

  @override
  String sharedServicesUpdateCheckFailed(String error) {
    return 'Impossible de rechercher les mises à jour : $error';
  }

  @override
  String get sharedServicesUpdateServerNotConfigured =>
      'Le serveur de mises à jour n\'est pas configuré dans cette version.';

  @override
  String get sharedServicesUpdateServerUnreachable =>
      'Impossible de joindre le serveur de mises à jour. Vérifiez votre connexion.';

  @override
  String sharedServicesUpdateServerHttp(int code) {
    return 'Le serveur de mises à jour a renvoyé HTTP $code.';
  }

  @override
  String get sharedServicesUpdateManifestInvalid =>
      'Le manifeste de mise à jour est invalide.';

  @override
  String get sharedServicesUpdateNoInstaller =>
      'Aucun installateur n\'est encore publié pour l\'architecture de cet appareil.';

  @override
  String sharedServicesUpdateNoAsset(String version) {
    return '$version trouvée, mais aucun installateur correspondant.';
  }

  @override
  String get sharedLanServerUp => 'Serveur actif';

  @override
  String get sharedLanServerUnreachable => 'Serveur injoignable';

  @override
  String get sharedLanWaitingForPair => 'en attente d\'association';

  @override
  String get sharedLanPaired => 'associé';

  @override
  String get sharedLanIdleLower => 'inactif';

  @override
  String get sharedLanPlayingLower => 'en lecture';

  @override
  String get sharedLanIdle => 'Inactif';

  @override
  String get sharedLanActive => 'Actif';

  @override
  String get sharedLanPlaying => 'En lecture';

  @override
  String get sharedLanDesktopOnline => 'Ordinateur en ligne';

  @override
  String get sharedLanPairWithDesktop =>
      'Associez-vous à un serveur Forja sur ordinateur dans Paramètres → LAN.';

  @override
  String get sharedLanDesktopOffline =>
      'Le serveur sur ordinateur est hors ligne. Les flux directs fonctionnent toujours.';

  @override
  String get sharedMiscBack => 'Retour';

  @override
  String get sharedMiscAirPlayCantPlay => 'AirPlay ne peut pas lire ce flux';

  @override
  String get sharedPlaybackOpeningPlayer => 'Ouverture du lecteur…';

  @override
  String get sharedPlaybackProbingStreams => 'Test des flux…';

  @override
  String sharedPlaybackProbingStreamsProgress(int done, int total) {
    return 'Test des flux ($done/$total)…';
  }

  @override
  String get sharedPlaybackCheckingServers => 'Vérification des serveurs…';

  @override
  String get sharedPlaybackFindingServers => 'Recherche de serveurs…';

  @override
  String get sharedPlaybackFindingForjaServers =>
      'Recherche de serveurs Forja…';

  @override
  String get sharedPlaybackStartingStream => 'Démarrage du flux…';

  @override
  String get sharedPlaybackHintStarting => 'Démarrage de la lecture';

  @override
  String get sharedPlaybackHintTesting => 'Test des liens lisibles';

  @override
  String get sharedPlaybackHintAsking => 'Demande de flux aux serveurs';

  @override
  String get sharedPlaybackHintLookingUp =>
      'Recherche des fournisseurs disponibles';

  @override
  String sharedPlaybackProbeSummary(int checked, int total, int ready) {
    return '$checked / $total vérifiés · $ready en ligne';
  }

  @override
  String sharedPlaybackProbeSummarySkipped(
    int checked,
    int total,
    int ready,
    int skipped,
  ) {
    return '$checked / $total vérifiés · $ready en ligne · $skipped ignorés sur TV';
  }

  @override
  String get sharedPlaybackSearchAgain => 'Rechercher à nouveau';

  @override
  String get sharedPlaybackSavedLinkBroken =>
      'Ce lien enregistré ne fonctionne plus';

  @override
  String get sharedPlaybackProbeWaiting => 'En attente';

  @override
  String get sharedPlaybackProbeChecking => 'Vérification';

  @override
  String get sharedPlaybackProbeUp => 'En ligne';

  @override
  String get sharedPlaybackProbeDown => 'Hors ligne';

  @override
  String get sharedPlaybackProbeSkipped => 'Ignoré';

  @override
  String get sharedPlaybackHideServers => 'Masquer les serveurs';

  @override
  String get sharedPlaybackShowServers => 'Afficher les serveurs';

  @override
  String get sharedPlaybackTapServerFirst =>
      'Touchez un serveur pour le vérifier en premier';

  @override
  String get sharedPlaybackPressBackToCancel =>
      'Appuyez sur Retour pour annuler';

  @override
  String get sharedPlaybackTryAgain => 'Réessayer';

  @override
  String get sharedPlaybackCouldNotStart => 'Impossible de démarrer la lecture';

  @override
  String get sharedPlaybackNoPluginsOn =>
      'Aucun plugin Forja n\'est activé pour ce titre. Ouvrez Sources → Forja et activez des fournisseurs.';

  @override
  String get sharedPlaybackNoWorkingStream =>
      'Aucun plugin Forja n\'a renvoyé de flux fonctionnel pour le moment.';

  @override
  String get sharedPlaybackNoProvidersEnabled =>
      'Aucun fournisseur Forja n\'est activé pour Green Play';

  @override
  String get sharedPlaybackNoProvidersMatchLanguages =>
      'Aucun fournisseur Forja ne correspond aux langues sélectionnées';

  @override
  String get sharedPlaybackUnableHandleLink => 'Impossible de traiter ce lien';

  @override
  String get sharedPlaybackFailedLoadVideo => 'Échec du chargement de la vidéo';

  @override
  String sharedPlaybackErrorWith(String error) {
    return 'Erreur : $error';
  }

  @override
  String get sharedPlaybackDrmAndroidOnly =>
      'Ce titre est protégé par DRM — la lecture sur ordinateur n\'est pas encore disponible.';

  @override
  String sharedPlaybackEpisodeNumber(int number) {
    return 'Épisode $number';
  }

  @override
  String sharedPlaybackLabelEpisode(String label, int episode) {
    return '$label · Épisode $episode';
  }

  @override
  String sharedPlaybackSeasonEpisode(int season, int episode) {
    return 'Saison $season · Épisode $episode';
  }

  @override
  String get shellNavbarName => 'Barre de navigation';

  @override
  String shellReloadingNamed(String name) {
    return 'Rechargement de $name…';
  }

  @override
  String shellNamedReloaded(String name) {
    return '$name rechargé';
  }

  @override
  String get shellSearchHint => 'Rechercher…';

  @override
  String shellSearchHintNamed(String label) {
    return 'Rechercher dans $label…';
  }

  @override
  String get shellUpdateDownloading => 'Téléchargement de la mise à jour…';

  @override
  String shellUpdateDownloadingVersion(String version) {
    return 'Téléchargement de Forja $version…';
  }

  @override
  String get shellUpdateSoftwareUpdate => 'Mise à jour logicielle';

  @override
  String get shellUpdateNewVersionReady => 'Une nouvelle version est prête';

  @override
  String shellUpdateYouAreOn(String version) {
    return 'Vous utilisez la v$version';
  }

  @override
  String get shellUpdateWhatsNew => 'Nouveautés';

  @override
  String get shellUpdateHintOkBrowse => 'OK pour parcourir';

  @override
  String get shellUpdateHintRailNotes =>
      '↑↓ versions  ·  → notes  ·  OK pour quitter';

  @override
  String get shellUpdateHintScrollVersions =>
      '↑↓ défiler  ·  ← versions  ·  OK pour quitter';

  @override
  String get shellUpdateHintScroll => '↑↓ défiler  ·  OK pour quitter';

  @override
  String get shellUpdateNoNotes =>
      'Aucune note de version n\'a été publiée pour cette mise à jour.';

  @override
  String shellUpdateNoNotesVersion(String version) {
    return 'Aucune note de version n\'a été publiée pour la v$version.';
  }

  @override
  String get shellUpdateContinueInBackground => 'Continuer en arrière-plan';

  @override
  String get shellUpdateReleasedToday => 'publiée aujourd\'hui';

  @override
  String get shellUpdateReleasedYesterday => 'publiée hier';

  @override
  String shellUpdateReleasedDaysAgo(int days) {
    return 'publiée il y a $days jours';
  }

  @override
  String shellUpdateFailed(String error) {
    return 'Échec de la mise à jour : $error';
  }

  @override
  String shellUpdateDownloadFailed(String error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String shellUpdateCouldNotOpen(String error) {
    return 'Impossible d\'ouvrir la mise à jour : $error';
  }

  @override
  String get shellUpdateInstall => 'Installer la mise à jour';

  @override
  String get shellUpdateSkipForNow => 'Pas maintenant';

  @override
  String get shellUpdateSeeFullChangelog =>
      'Voir le changelog complet sur le web';

  @override
  String get shellUpdateViewFullChangelog => 'Voir le changelog complet';

  @override
  String get shellUpdateDownloadComplete => 'Téléchargement terminé';

  @override
  String get shellUpdateDownloadCompleteTitle => 'Téléchargement\nterminé';

  @override
  String get shellUpdateMustCloseWindows =>
      'Forja doit se fermer avant l\'installation de la mise à jour. Choisissez Installer pour fermer Forja et lancer l\'installateur, ou reportez à plus tard.';

  @override
  String get shellUpdateMustCloseMac =>
      'Forja doit se fermer avant l\'installation de la mise à jour. Choisissez Installer pour fermer Forja et ouvrir l\'image disque, ou reportez à plus tard.';

  @override
  String shellUpdateMakeExecutable(String fileName) {
    return 'Rendez le fichier exécutable, puis lancez-le :\nchmod +x \"$fileName\"\n./$fileName';
  }

  @override
  String get shellUpdateInstallAndClose => 'Installer et fermer Forja';

  @override
  String get shellUpdateDone => 'Terminé';

  @override
  String get shellUpdateOpenDownloads => 'Ouvrir le dossier de téléchargements';

  @override
  String get shellProfile => 'Profil';

  @override
  String get shellGuest => 'Invité';

  @override
  String get shellEmptyPluginsTitle => 'Plugins';

  @override
  String get shellEmptyPluginsBodyTv =>
      'Installez des packs hub et stream depuis une URL ou un profil.';

  @override
  String get shellEmptyPluginsBody =>
      'Installez des packs hub et stream depuis une URL de manifeste, ou synchronisez les packs de votre profil.';

  @override
  String get shellEmptyAddonsBodyTv =>
      'IPTV, Live Sports, torrent, Stremio, Nuvio, et plus.';

  @override
  String get shellEmptyAddonsBody =>
      'Activez IPTV, Live Sports, torrent, Stremio, Nuvio et d\'autres surfaces de lecture.';

  @override
  String get shellEmptyFeaturesBodyTv =>
      'Choisissez les onglets affichés dans la barre.';

  @override
  String get shellEmptyFeaturesBody =>
      'Choisissez les onglets affichés : Accueil, Anime, IPTV, Live Sports, Listes, et plus.';

  @override
  String get shellEmptyTitle => 'Activez une fonctionnalité pour commencer';

  @override
  String get shellEmptyHint => 'Choisissez Plugins, Addons ou Fonctionnalités.';

  @override
  String get shellPressBackAgainToExit =>
      'Appuyez de nouveau sur Retour pour quitter';

  @override
  String get shellPressExitAgainToExit =>
      'Appuyez de nouveau sur Quitter pour quitter';

  @override
  String get shellDismissCategories => 'Fermer les catégories';

  @override
  String get shellCategories => 'Catégories';

  @override
  String get shellUpdating => 'Mise à jour';

  @override
  String get accountAvatarCategoryCharacters => 'Personnages';

  @override
  String get accountAvatarCategoryCreatures => 'Créatures';

  @override
  String get accountAvatarCategorySpace => 'Espace';

  @override
  String get accountAvatarCategoryRetro => 'Rétro';

  @override
  String get foundationReadMore => 'Lire la suite';

  @override
  String get foundationReadLess => 'Voir moins';

  @override
  String get foundationRetry => 'Réessayer';

  @override
  String get foundationBack => 'Retour';

  @override
  String get foundationNothingHere => 'Rien ici';

  @override
  String get foundationNoCategories => 'Aucune catégorie';

  @override
  String get foundationNoMatches => 'Aucun résultat';

  @override
  String get foundationSearch => 'Rechercher';

  @override
  String get foundationAll => 'Tous';

  @override
  String get foundationFactName => 'Nom';

  @override
  String get foundationFactStatus => 'Statut';

  @override
  String get foundationFactLanguage => 'Langue';

  @override
  String get foundationFactFirstAired => 'Première diffusion';

  @override
  String get foundationFactLastAired => 'Dernière diffusion';

  @override
  String get foundationFactSeasons => 'Saisons';

  @override
  String get foundationFactEpisodes => 'Épisodes';

  @override
  String get foundationFactNetwork => 'Chaîne';

  @override
  String get foundationFactReleaseDate => 'Date de sortie';

  @override
  String get foundationFactRuntime => 'Durée';

  @override
  String get foundationFactProduction => 'Production';

  @override
  String get foundationFactOrigin => 'Origine';

  @override
  String get foundationFactCreatedBy => 'Créé par';

  @override
  String get foundationFactBudget => 'Budget';

  @override
  String get foundationFactRevenue => 'Recettes';

  @override
  String get foundationStatusReleased => 'Sorti';

  @override
  String get foundationStatusEnded => 'Terminé';

  @override
  String get foundationStatusReturningSeries => 'Série en cours';

  @override
  String get foundationStatusInProduction => 'En production';

  @override
  String get foundationStatusCanceled => 'Annulé';

  @override
  String get foundationStatusPlanned => 'Prévu';

  @override
  String get foundationStatusPostProduction => 'Post-production';

  @override
  String get foundationStatusRumored => 'Rumeur';

  @override
  String get foundationMonthJan => 'janv.';

  @override
  String get foundationMonthFeb => 'févr.';

  @override
  String get foundationMonthMar => 'mars';

  @override
  String get foundationMonthApr => 'avr.';

  @override
  String get foundationMonthMay => 'mai';

  @override
  String get foundationMonthJun => 'juin';

  @override
  String get foundationMonthJul => 'juil.';

  @override
  String get foundationMonthAug => 'août';

  @override
  String get foundationMonthSep => 'sept.';

  @override
  String get foundationMonthOct => 'oct.';

  @override
  String get foundationMonthNov => 'nov.';

  @override
  String get foundationMonthDec => 'déc.';

  @override
  String foundationDatePattern(String month, String day, String year) {
    return '$day $month $year';
  }

  @override
  String get foundationWordSeeAll => 'Voir tout';

  @override
  String get foundationWordBecauseYouWatched => 'Parce que vous avez regardé';

  @override
  String get foundationWordPlanToWatch => 'À regarder';

  @override
  String get foundationWordWatching => 'En cours';

  @override
  String get foundationWordOnHold => 'En pause';

  @override
  String get foundationWordCompleted => 'Terminé';

  @override
  String get foundationWordDropped => 'Abandonné';

  @override
  String get foundationWordEpisodes => 'Épisodes';

  @override
  String get foundationWordReload => 'Recharger';

  @override
  String get foundationWordClose => 'Fermer';

  @override
  String get foundationWordComingSoon => 'Bientôt disponible';

  @override
  String get foundationWordScore => 'Note';

  @override
  String get foundationWordAnyScore => 'Toutes les notes';

  @override
  String get foundationWordYear => 'Année';

  @override
  String get foundationWordAnyYear => 'Toutes les années';

  @override
  String get foundationWordGenre => 'Genre';

  @override
  String get foundationWordCountry => 'Pays';

  @override
  String get foundationWordLanguage => 'Langue';

  @override
  String get foundationWordFilms => 'Films';

  @override
  String get foundationWordSeries => 'Séries';

  @override
  String get foundationWordAction => 'Action';

  @override
  String get foundationWordAdventure => 'Aventure';

  @override
  String get foundationWordAnimation => 'Animation';

  @override
  String get foundationWordComedy => 'Comédie';

  @override
  String get foundationWordCrime => 'Crime';

  @override
  String get foundationWordDocumentary => 'Documentaire';

  @override
  String get foundationWordDrama => 'Drame';

  @override
  String get foundationWordFamily => 'Famille';

  @override
  String get foundationWordFantasy => 'Fantastique';

  @override
  String get foundationWordHistory => 'Histoire';

  @override
  String get foundationWordHorror => 'Horreur';

  @override
  String get foundationWordMusic => 'Musique';

  @override
  String get foundationWordMystery => 'Mystère';

  @override
  String get foundationWordRomance => 'Romance';

  @override
  String get foundationWordSciFi => 'Science-fiction';

  @override
  String get foundationWordThriller => 'Thriller';

  @override
  String get foundationWordWar => 'Guerre';

  @override
  String get foundationWordWestern => 'Western';

  @override
  String get foundationWordKids => 'Enfants';

  @override
  String get foundationWordUsa => 'États-Unis';

  @override
  String get foundationWordUk => 'Royaume-Uni';

  @override
  String get foundationWordFrance => 'France';

  @override
  String get foundationWordGermany => 'Allemagne';

  @override
  String get foundationWordJapan => 'Japon';

  @override
  String get foundationWordKorea => 'Corée';

  @override
  String get foundationWordIndia => 'Inde';

  @override
  String get foundationWordItaly => 'Italie';

  @override
  String get foundationWordSpain => 'Espagne';

  @override
  String get foundationWordCanada => 'Canada';

  @override
  String get foundationWordAustralia => 'Australie';

  @override
  String get foundationWordChina => 'Chine';

  @override
  String get foundationWordBrazil => 'Brésil';

  @override
  String get foundationWordMexico => 'Mexique';

  @override
  String get foundationWordSweden => 'Suède';

  @override
  String get foundationWordNorway => 'Norvège';

  @override
  String get foundationWordDenmark => 'Danemark';

  @override
  String get foundationWordTurkey => 'Turquie';

  @override
  String get foundationWordHongKong => 'Hong Kong';

  @override
  String get foundationWordTaiwan => 'Taïwan';

  @override
  String get foundationWordThailand => 'Thaïlande';

  @override
  String get foundationWordEnglish => 'Anglais';

  @override
  String get foundationWordJapanese => 'Japonais';

  @override
  String get foundationWordKorean => 'Coréen';

  @override
  String get foundationWordFrench => 'Français';

  @override
  String get foundationWordSpanish => 'Espagnol';

  @override
  String get foundationWordGerman => 'Allemand';

  @override
  String get foundationWordItalian => 'Italien';

  @override
  String get foundationWordPortuguese => 'Portugais';

  @override
  String get foundationWordChinese => 'Chinois';

  @override
  String get foundationWordHindi => 'Hindi';

  @override
  String get foundationWordArabic => 'Arabe';

  @override
  String get foundationWordTurkish => 'Turc';

  @override
  String get foundationWordThai => 'Thaï';

  @override
  String get foundationWordSwedish => 'Suédois';

  @override
  String get foundationWordNorwegian => 'Norvégien';

  @override
  String get foundationWordDanish => 'Danois';

  @override
  String get foundationWordSub => 'VOSTFR';

  @override
  String get foundationWordDub => 'VF';
}
