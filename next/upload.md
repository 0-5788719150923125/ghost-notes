# Upload

## Status

- **Built:** the Upload card (code name `youtube`) with Goes to: YouTube, TikTok or both. Title, description and tags are
  shared; YouTube's rows and TikTok's rows show while each is picked. An export goes up to YouTube first, then to TikTok,
  and the exporter's line says both. `tests/export/tiktok_check.gd` holds TikTok's sign-in, upload, post and draft against
  a stand-in for TikTok on 127.0.0.1.
- **Built:** a painted thumbnail's Refine… (under it and in its full-size window): a painter changes only what the author
  asks in the one shown, and it lands as a new version that goes up (`YouTubeThumbnail.refine`, rules/youtube/thumbnail.yaml
  `refine`). Not yet tried on a real painter; the user still has to judge whether its words stay put when not asked about.
- **Not yet tried:** a real TikTok account and app. Everything about TikTok is built from its documentation alone.
- **The user still has to judge:** whether drafts or posts suit; the caption's shape; whether TikTok's portrait export
  (Medium frame 9:16) should be offered when TikTok is a target.

## Setting TikTok up

1. Make an app on TikTok for Developers (developers.tiktok.com). Add **Login Kit** with the **Desktop** platform and the
   **Content Posting API** (turn on Direct Post only to post straight to the account).
2. Register the redirect URI `http://127.0.0.1:*/callback/` (TikTok allows a wildcard port for desktop apps). Without the
   wildcard, the sign-in's random port will not match.
3. In a sandbox app, add the TikTok account as a target user.
4. On the Upload card, tick TikTok under Goes to, press **Client…** and paste the Client key and Client secret.
5. **Sign in** opens the browser.

## How it goes up

- **Draft in the TikTok app** (scope `video.upload`, the default): the video lands in the TikTok app's inbox, where its
  author writes the caption, picks who sees it and posts it. This works for an app TikTok has not audited, with any
  privacy. At most five drafts may wait a day.
- **Post** (scope `video.publish`): posted straight away with the card's caption and settings. TikTok's Direct Post rules
  shape the rows: who sees it is picked from what the account offers and starts unpicked; comments, Duets and Stitches
  start off; TikTok's music terms line shows above the post. The video is labeled AI-generated unless cleared.
- **An app TikTok has not audited** may post only to a private account, and only as Only me (`unaudited_client_can_only_post_to_private_accounts`).
  Making posts public takes TikTok's audit of the app.

## Open

- Login Kit for Desktop documents its PKCE challenge as the HEX of SHA-256, not RFC 7636's base64url (`TikTok.challenge`).
  If the first real sign-in fails at the token exchange, that is the first thing to try the other way.
- Chunk size is 10,000,000 bytes, inside TikTok's 5-64 MB whichever way it counts a megabyte.
- TikTok holds 3 minutes for every creator, and up to 10 for some: a longer export is refused before it is sent, naming
  the account's limit.
- A cut-off TikTok upload starts over (its upload address lasts an hour and does not say how much it holds).
