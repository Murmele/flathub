# HappyFoto smart moments backend

Notes on the server API used by the official "smart moments" desktop app (v1.22), collected
from the app's generated API client (`@hf-designer/api`) and from network traffic of the
Linux repack (`packaging/electron`). This is not an official or stable API.

## Tenants

| Tenant | Base URL |
|---|---|
| DE | `https://smartmoments.happyfoto.de` |
| AT | `https://smartmoments.happyfoto.at` |
| CZ | `https://smartmoments.happyfoto.cz` |
| SK | `https://smartmoments.happyfoto.sk` |

## Headers

All requests to the base URL carry these headers. Without them, even `/api/public/...`
endpoints answer `401`.

```
X-Client-Version: 1.22.0
X-Locale: de_DE
X-Platform-Type: DESKTOP
X-Platform-OS: <os>
X-Platform-OS-Version: <version>
X-Requested-With: at.happyfoto.designer.native
```

An outdated `X-Client-Version` gets `400` with `globalErrors[0].code == "client.VersionNotSupported"`.

## Product data, prices and design assets

`GET /api/public/provided-assets/v2/versionInfo` returns

```jsonc
{
  "baseUrl": "https://happyfoto-2.objectdata.io/<bucket>/files/",
  "files": [{ "id": "<uuid>", "version": 2, "size": 490331, "type": 24 }, ...],
  "oldStaticResourceIdToFileId": {
    "product-data-PB_A4P_HC-1.22-de_DE": "<file id>",
    "prices-1.22": "<file id>",
    "i18n-de_DE": "<file id>",
    ...
  },
  "layouts": [...], "backgrounds": [...], "cliparts": [...], "complexBorders": [...],
  "productIdToLayoutMetadataFileId": {...}, "staticFiles": {...}
}
```

A file is downloaded (no authentication) from `{baseUrl}{id}/{version}`.

### Product data (`product-data-<KEY>-<major.minor>-<locale>`)

```jsonc
{
  "key": "PB_A4P_HC", "type": "book",
  "displayInfo": { "name": "Fotobuch Hardcover ca. A4 hoch", "displayAttributeValues": [...] },
  "attributeValues": [{ "key": "minimumResolution", "value": "100" }, { "key": "renderResolution", "value": "300" }, ...],
  "productVariants": [                       // one variant per page count
    { "key": "PB_A4P_HC_24", "attributeValues": [{ "key": "pages", "value": "24" }],
      "contentAreas": [{ "name": "Cover", "contentLayout": "cover-8" },
                       { "name": "Seite 1", "contentLayout": "page-first" },
                       { "name": "Seite 2-3", "contentLayout": "page" }, ...,
                       { "contentLayout": "page-last" }] }
  ],
  "contentLayouts": [                        // spread geometry, mm
    { "id": "cover-8", "contentLayoutType": "COVER", "bounds": {...},
      "designRegions": [{ "region": { "x": 0.5, "y": 0.5, "width": 444, "height": 306 },
        "layoutRegionSets": [{ "layoutId": "page-regions", "layoutRegions": [
          { "layoutRegionId": "backCover", "x": 0, "y": 0 },
          { "layoutRegionId": "spine-8", "x": 218, "y": 0 },
          { "layoutRegionId": "frontCover", "x": 226, "y": 0 }] }] }] }
  ],
  "layoutRegions": [                         // printable areas incl. bleed, mm
    { "id": "page", "type": "Page", "width": 203, "height": 280, "bleed": { "top": 4, "right": 4, "bottom": 4, "left": 4 } },
    { "id": "frontCover", "type": "FrontCover", "width": 218, "height": 306, "bleed": { "top": 13, "right": 14, "bottom": 13, "left": 10 } },
    ...
  ]
}
```

The spine width depends on the page count, via the cover layout of each variant. For
`PB_A4P_HC` it is 8 mm (24–38 pages) up to 28 mm (300 pages). Up to 240 pages the page count
goes in steps of 2, above that in steps of 20.

### Prices (`prices-<major.minor>`)

```json
{ "expirationDate": "...", "products": [
  { "productKey": "PB_A4P_HC_24", "prices": [{ "validFrom": "...", "price": 28.9, "formattedPrice": "28,90 €", "priceUnit": "PIECE" }] } ] }
```

## Login

1. Open `GET /api/public/tryLogin?authenticate=true&url=designer-desktop://login` in a browser.
2. After the login the server redirects to `designer-desktop://login?sname=<cookie name>&sid=<session id>`.
3. Later requests send the cookie `<sname>=<sid>` and the header `X-Authentication: <sid>`.
4. `GET /api/public/currentUser` returns the logged-in user.

## Adding a project to the shopping cart ("+ Warenkorb")

The server renders the print files; the client only uploads the project model and the
original photos.

1. `POST /api/secure/resource` with the `ProjectModel` as body returns the resources the
   server does not have yet (`MissingResourceDto[]`).
2. For each missing resource:
   1. `GET /api/secure/resource/{resourceId}/upload-url?contentLength=&imageWidth=&imageHeight=&isPreviewImage=false`
      returns a pre-signed upload URL.
   2. `PUT` the file bytes to that URL.
   3. `PUT /api/secure/resource/{resourceId}/confirm-upload?imageWidth=`
3. `POST /api/secure/project/v2` with
   `{ "projectModel": <ProjectModel>, "projectType": "SHOPPINGCARTPROJECT", "projectOrigin": ... }`.
   An existing cart project is updated with `PUT /api/secure/project/v2/{id}`; check it with
   `GET /api/secure/project/v2/{id}/is-in-shopping-cart`.
4. Optionally upload a preview image (a resource with `isPreviewImage=true`).
5. `GET /api/public/redirect/checkout?cookieConsent=false&embed=false` returns `{ "url": ... }`,
   which is opened in the browser to finish the order.

Cloud projects use the same `/api/secure/project/v2` endpoints (`GET .../list`, `POST`, `PUT`,
`DELETE`, `.../duplicate`, `.../name`).

## Project model (`.hfsm`)

The official app stores local projects as JSON `<name>.hfsm` and a sibling folder
`<name>_hfsm/` that holds copies of the photos (`<resourceId>.<ext>`). Key fields
(`modelVersion` 35):

* `BookProjectModel`: `id`, `type: "book"`, `name`, `productKey`, `productVariantKey`,
  `resources[]`, `pages[]` (`{pageId, designRegionId, resources: [pageResourceId]}`),
  `pageResources[]`.
* `ProjectPageResource`: `framePlacement {centerX, centerY, width, height}` (mm),
  `frameRotation` (degrees), `imageTransform {rotation, offsetX, offsetY, scaleX, scaleY}`,
  `imageStyle`, `tags` (`BACKGROUND_IMAGE_FULL|LEFT|RIGHT`, …).
* Resource types: `photoProjectResource`, `richTextProjectResource` (HTML content),
  `colorPageBackgroundProjectResource` (`position` Left|Right|Full|Spine, `color`),
  `clipartProjectResource`, `backgroundProjectResource`, `placeHolderProjectResource`.
