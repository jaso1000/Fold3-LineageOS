package org.fold3.dolby;

import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;

/** Quick Settings tile: Dolby Atmos on/off. */
public class DolbyTileService extends TileService {
    private DolbyApp app() {
        return (DolbyApp) getApplication();
    }

    @Override
    public void onStartListening() {
        update();
    }

    @Override
    public void onClick() {
        app().setOn(!app().isOn());
        update();
    }

    private void update() {
        Tile tile = getQsTile();
        if (tile == null) return;
        tile.setState(app().isOn() ? Tile.STATE_ACTIVE : Tile.STATE_INACTIVE);
        tile.updateTile();
    }
}
