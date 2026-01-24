/*
    Scanbot Image Picker Cordova Plugin
    Copyright (c) 2021 doo GmbH

    This code is licensed under MIT license (see LICENSE for details)

    Created by Marco Saia on 07.05.2021
*/
package earth.actualize.cordova.plugin.utils;

import android.net.Uri;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.HashMap;
import java.util.Map;

public class JsonArgs {

    private final Map<String, Object> argsMap = new HashMap<String, Object>();

    public JsonArgs put(final String key, final String value) {
        this.argsMap.put(key, value);
        return this;
    }

    public JsonArgs put(final String key, final int value) {
        this.argsMap.put(key, value);
        return this;
    }

    public JsonArgs put(final String key, final double value) {
        this.argsMap.put(key, value);
        return this;
    }

    public JsonArgs put(final String key, final float value) {
        this.argsMap.put(key, value);
        return this;
    }

    public JsonArgs put(final String key, final boolean value) {
        this.argsMap.put(key, value);
        return this;
    }

    public JsonArgs put(final String key, final JSONArray value) {
        this.argsMap.put(key, value);
        return this;
    }

    public JsonArgs put(final String key, final JsonArgs value) {
        this.argsMap.put(key, value.jsonObj());
        return this;
    }

    public JsonArgs put(final String key, final JSONObject value) {
        this.argsMap.put(key, value);
        return this;
    }

    public JSONObject jsonObj() {
        return new JSONObject(this.argsMap);
    }

    public Map<String, Object> getArgsMap() {
        return this.argsMap;
    }

    public static JsonArgs kvp(String key, Uri value) {
        return new JsonArgs().put(key, value.toString());
    }

    public static JsonArgs kvp(String key, Boolean value) {
        return new JsonArgs().put(key, value.toString());
    }

    public static JsonArgs kvp(String key, String value) {
        return new JsonArgs().put(key, value);
    }
}