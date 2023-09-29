HVAC_MODES = {}
FAN_MODES = {}
PRESET_MODES = {}

HAS_REMOTE_SENSOR = false
REMOTE_SENSOR_UNAVAIL = false
HAS_HUMIDITY = false
SELECTED_SCALE = ""

function DRV.OnDriverLateInit(init)
    SELECTED_SCALE = C4:PersistGetValue("CurrentTemperatureScale") or "FAHRENHEIT"
    HAS_REMOTE_SENSOR =  C4:PersistGetValue("RemoteSensor") or false
    local tParams = {
        IN_USE = HAS_REMOTE_SENSOR
    }
    RFP.SET_REMOTE_SENSOR("","",tParams)
    print("creating refresh timer")
    C4:SetTimer(30000, function(timer, skips) CheckInTimer(timer, skips) end, true)
    if (SELECTED_SCALE == "FAHRENHEIT") then
        print("Setting scale to °F")
        SetCurrentTemperatureScale("FAHRENHEIT")
    else
        print("Setting scale to °C")
        SetCurrentTemperatureScale("CELSIUS")
    end
end

function DRV.OnBindingChanged(idBinding, strClass, bIsBound)   
    if(bIsBound) then
        print("Bound binding %d", idBinding)

        if idBinding == 1 then
    		C4:SendToProxy(idBinding, "QUERY_SETTINGS", {})
    		C4:SendToProxy(idBinding, "GET_SENSOR_VALUE", {})
        end
    else
        print("Unbound binding %d", idBinding)
    end
end

function OPC.Precision(strProperty)
    local precisionStr = Properties["Precision"]
    local precisionStrF = Properties["Precision"]
    if precisionStrF == ".1" then precisionStrF = ".2" end
    local tParams = {
        TEMPERATURE_RESOLUTION_C = precisionStr,
        TEMPERATURE_RESOLUTION_F = precisionStrF,
        OUTDOOR_TEMPERATURE_RESOLUTION_C = precisionStr,
        OUTDOOR_TEMPERATURE_RESOLUTION_F = precisionStrF,
    }
    print("Sending to proxy: " , C4:SendToProxy(5001, 'DYNAMIC_CAPABILITIES_CHANGED', tParams, "NOTIFY"))

end

function RFP.SET_REMOTE_SENSOR(idBinding, strCommand, tParams)
    HAS_REMOTE_SENSOR = tParams.IN_USE
    C4:SendToProxy(5001, "REMOTE_SENSOR_CHANGED", tParams, "NOTIFY")
    C4:PersistSetValue("RemoteSensor", tParams.IN_USE, false)
    if HAS_REMOTE_SENSOR == false then
        tParams = {
            entity = EntityID
        }
	    C4:SendToProxy(999, "HA_GET_STATE", tParams)
    end
end

function RFP.VALUE_INITIALIZE(idBinding, strCommand, tParams)
    print("temperature initialize!")
    RFP.VALUE_INITIALIZED(idBinding, strCommand, tParams)
end

function RFP.VALUE_INITIALIZED(idBinding, strCommand, tParams)
    print("temperature initialize(d)!")
    if HAS_REMOTE_SENSOR and idBinding == 1 then
        REMOTE_SENSOR_UNAVAIL = false
        local ScaleStr = ""
        local SensorValue
        Connected = true
        local connectParams =
            {
            CONNECTED = "true"
        }
        print("Sending to proxy: Connection ", tostring(connectParams.CONNECTED))
        C4:SendToProxy(5001, "CONNECTION", connectParams, "NOTIFY")

        if (tParams.CELSIUS ~= nil and SELECTED_SCALE == "CELSIUS") then
            SensorValue = tonumber(tParams.CELSIUS)
        elseif (tParams.FAHRENHEIT ~= nil and SELECTED_SCALE == "FAHRENHEIT") then
            SensorValue = tonumber(tParams.FAHRENHEIT)
        else
            SensorValue = tonumber(tParams.FAHRENHEIT)
        end

        local TimeStamp = (tParams.TIMESTAMP ~= nil) and tParams.TIMESTAMP or tostring(os.time())
        print("Sending initialized to thermostat proxy")
        C4:SendToProxy(5001, "VALUE_INITIALIZED", { STATUS = "active", TimeStamp}, "NOTIFY")
        print("sending temp changed to thermostat proxy")
        C4:SendToProxy(5001, "TEMPERATURE_CHANGED", { TEMPERATURE = tostring(SensorValue), SCALE = ScaleStr }, "NOTIFY")
    end
end

function RFP.VALUE_CHANGED(idBinding, strCommand, tParams)
    print("value_changed called. has remote sensor:", HAS_REMOTE_SENSOR, " remote sensor unavail: ", REMOTE_SENSOR_UNAVAIL)
    if HAS_REMOTE_SENSOR and idBinding == 1 then
        local SensorValue
        if(HAS_REMOTE_SENSOR and REMOTE_SENSOR_UNAVAIL) then
            REMOTE_SENSOR_UNAVAIL = true
            Connected = false
            local tParams =
            {
                CONNECTED = "false"
            }
            C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
        end
        if (tParams.CELSIUS ~= nil and SELECTED_SCALE == "CELSIUS") then
            print("scale selected is °C and tParams.CELSIUS is ", tostring(tParams.CELSIUS))
            SensorValue = tonumber(tParams.CELSIUS)
        elseif (tParams.FAHRENHEIT ~= nil and SELECTED_SCALE == "FAHRENHEIT") then
            print("scale selected is °F and tParams.FAHRENHEIT is ", tostring(tParams.FAHRENHEIT))
            SensorValue = tonumber(tParams.FAHRENHEIT)
        else
            print("no scale selected! defaulting to °F and tParams.FAHRENHEIT is ", tostring(tParams.FAHRENHEIT))
            SensorValue = tonumber(tParams.FAHRENHEIT)
        end

        C4:SendToProxy(5001, "TEMPERATURE_CHANGED", { TEMPERATURE = tostring(SensorValue), SCALE = SELECTED_SCALE }, "NOTIFY")
    end
end

function RFP.VALUE_UNAVAILABLE(idBinding, strCommand, tParams)
    if HAS_REMOTE_SENSOR and idBinding == 1 then
        REMOTE_SENSOR_UNAVAIL = true
        Connected = false
        local tParams =
        {
            CONNECTED = "false"
        }

        C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
    end
    
end

function RFP.SET_MODE_HVAC(idBinding, strCommand, tParams)
    local mode = tParams["MODE"]

    if mode == "Auto" then
        mode = "heat_cool"
    end

    local hvacModeServiceCall = {
        domain = "climate",
        service = "set_hvac_mode",

        service_data = {
            hvac_mode = mode
        },

        target = {
            entity_id = EntityID
        }
    }

    tParams = {
        JSON = JSON:encode(hvacModeServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_SCALE(bindingID, action, tParams)
    SetCurrentTemperatureScale(tParams.SCALE)
end

function RFP.SET_MODE_FAN(idBinding, strCommand, tParams)
    local mode = tParams["MODE"]

    local hvacModeServiceCall = {
        domain = "climate",
        service = "set_fan_mode",

        service_data = {
            fan_mode = mode
        },

        target = {
            entity_id = EntityID
        }
    }

    tParams = {
        JSON = JSON:encode(hvacModeServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_SETPOINT_HEAT(idBinding, strCommand, tParams)
    local cTemperature = tonumber(tParams["CELSIUS"])
    local fTemperature = tonumber(tParams["FAHRENHEIT"])
    local temperatureServiceCall = {}

    if fTemperature <= 0 or cTemperature <= 0 then
        return
    end

    if MODE == "heat_cool" then
        if SELECTED_SCALE == "FAHRENHEIT" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    target_temp_low = fTemperature,
                    target_temp_high = HIGH_TEMP
                },

                target = {
                    entity_id = EntityID
                }
            }
        elseif SELECTED_SCALE == "CELSIUS" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    target_temp_low = cTemperature,
                    target_temp_high = HIGH_TEMP
                },

                target = {
                    entity_id = EntityID
                }
            }
        else
            print("Something is really wrong, not a valid temperature scale defined in PersistentData!!")
            return
        end
    elseif MODE == "heat" then
        if SELECTED_SCALE == "FAHRENHEIT" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    temperature = fTemperature
                },

                target = {
                    entity_id = EntityID
                }
            }
        elseif SELECTED_SCALE == "CELSIUS" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    temperature = cTemperature
                },

                target = {
                    entity_id = EntityID
                }
            }
        else
            print("Something is really wrong, not a valid temperature scale defined in PersistentData!!")
            return
        end
    end

    tParams = {
        JSON = JSON:encode(temperatureServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_SETPOINT_COOL(idBinding, strCommand, tParams)
    local cTemperature = tonumber(tParams["CELSIUS"])
    local fTemperature = tonumber(tParams["FAHRENHEIT"])
    local temperatureServiceCall = {}

    if fTemperature <= 0 then
        return
    end

    if MODE == "heat_cool" then
        if SELECTED_SCALE == "FAHRENHEIT" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    target_temp_low = fTemperature,
                    target_temp_high = HIGH_TEMP
                },

                target = {
                    entity_id = EntityID
                }
            }
        elseif SELECTED_SCALE == "CELSIUS" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    target_temp_low = cTemperature,
                    target_temp_high = HIGH_TEMP
                },

                target = {
                    entity_id = EntityID
                }
            }
        else
            print("Something is really wrong, not a valid temperature scale defined in PersistentData!!")
            return
        end
    elseif MODE == "cool" then
        if SELECTED_SCALE == "FAHRENHEIT" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    temperature = fTemperature
                },

                target = {
                    entity_id = EntityID
                }
            }
        elseif SELECTED_SCALE == "CELSIUS" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    temperature = cTemperature
                },

                target = {
                    entity_id = EntityID
                }
            }
        else
            print("Something is really wrong, not a valid temperature scale defined in PersistentData!!")
            return
        end
    end

    tParams = {
        JSON = JSON:encode(temperatureServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.RECEIEVE_STATE(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.response)

    local stateData

    if jsonData ~= nil then
        stateData = jsonData
    end

    Parse(stateData)
end

function RFP.RECEIEVE_EVENT(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.data)

    local eventData

    if jsonData ~= nil then
        eventData = jsonData["event"]["data"]["new_state"]
    end

    Parse(eventData)
end

function Parse(data)
    if data == nil then
        print("NO DATA")
        return
    end

    if data["entity_id"] ~= EntityID then
        return
    end

    local attributes = data["attributes"]
    local state = data["state"]

    if state == "unavailable" or attributes == nil or (REMOTE_SENSOR_UNAVAIL and HAS_REMOTE_SENSOR) then
        Connected = false
        local tParams =
        {
            CONNECTED = "false"
        }

        C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
        return
    end

    if not Connected and state ~= "unavailable" and (REMOTE_SENSOR_UNAVAIL and HAS_REMOTE_SENSOR) then
        Connected = true

        local tParams =
        {
            CONNECTED = "true"
        }

        C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
    end

    local selectedAttribute = attributes["hvac_modes"]
    if selectedAttribute ~= nil and not TablesMatch(selectedAttribute, HVAC_MODES) then
        HVAC_MODES = attributes["hvac_modes"]

        local modes = table.concat(HVAC_MODES, ",")

        modes = modes:gsub("heat_cool", "Auto")

        local tParams = {
            MODES = modes
        }

        C4:SendToProxy(5001, 'ALLOWED_HVAC_MODES_CHANGED', tParams, "NOTIFY")
    end

    selectedAttribute = attributes["fan_modes"]
    if selectedAttribute ~= nil and not TablesMatch(selectedAttribute, FAN_MODES) then
        FAN_MODES = attributes["fan_modes"]

        local modes = table.concat(FAN_MODES, ",")

        local tParams = {
            MODES = modes
        }

        C4:SendToProxy(5001, 'ALLOWED_FAN_MODES_CHANGED', tParams, "NOTIFY")
    end

    selectedAttribute = attributes["preset_modes"]
    if selectedAttribute ~= nil and not TablesMatch(selectedAttribute, PRESET_MODES) then
        PRESET_MODES = attributes["preset_modes"]
    end

    if attributes["current_temperature"] ~= nil and not HAS_REMOTE_SENSOR then
        local temperature = tonumber(attributes["current_temperature"])

        local tParams = {
            TEMPERATURE = temperature,
            SCALE = SELECTED_SCALE
        }

        C4:SendToProxy(5001, "TEMPERATURE_CHANGED", tParams, "NOTIFY")
    end

    selectedAttribute = attributes["current_humidity"]
    if selectedAttribute ~= nil then
        local tParams = {
            HUMIDITY = tonumber(attributes["current_humidity"])
        }

        C4:SendToProxy(5001, "HUMIDITY_CHANGED", tParams, "NOTIFY")

        if HAS_HUMIDITY == false then
            HAS_HUMIDITY = true

            local tParams = {
                HAS_HUMIDITY = HAS_HUMIDITY
            }

            C4:SendToProxy(5001, 'DYNAMIC_CAPABILITIES_CHANGED', tParams, "NOTIFY")
        end
    else
        if HAS_HUMIDITY == true then
            HAS_HUMIDITY = false

            local tParams = {
                HAS_HUMIDITY = HAS_HUMIDITY
            }

            C4:SendToProxy(5001, 'DYNAMIC_CAPABILITIES_CHANGED', tParams, "NOTIFY")
        end
    end

    if attributes["fan_mode"] ~= nil then
        local value = attributes["fan_mode"]

        local tParams = {
            MODE = value
        }

        C4:SendToProxy(5001, "FAN_MODE_CHANGED", tParams, "NOTIFY")
    end

    if attributes["fan_state"] ~= nil then
        local value = attributes["fan_state"]
        local fanStateString = ""
        if string.find(value, "off") or string.find(value, "Idle") then
            fanStateString = "Off"
        else
            fanStateString = "On"
        end

        local tParams = {
            STATE = fanStateString
        }

        C4:SendToProxy(5001, "FAN_STATE_CHANGED", tParams, "NOTIFY")
    else
        local hvacActionValue = attributes["hvac_action"]
        local fanModeValue = attributes["fan_mode"]
        local fanStateString = ""
        if ((not string.find(hvacActionValue, "idle")) or (string.find(fanModeValue, "on"))) then
            fanStateString = "On"
        else
            fanStateString = "Off"
        end

        local tParams = {
            STATE = fanStateString
        }

        C4:SendToProxy(5001, "FAN_STATE_CHANGED", tParams, "NOTIFY")
    end


    if attributes["hvac_action"] ~= nil then
        local value = attributes["hvac_action"]
        local c4ReportableState = ""
        if (string.find(value, "cool")) then
            c4ReportableState = "Cool"
        else
            if (string.find(value, "heat")) then
                c4ReportableState = "Heat"
            else
                c4ReportableState = "Off"
            end
        end
        local tParams = {
            STATE = c4ReportableState
        }

        C4:SendToProxy(5001, "HVAC_STATE_CHANGED", tParams, "NOTIFY")
    end


    if state ~= nil then
        MODE = state

        if state == "heat_cool" then
            state = "Auto"
        end

        local tParams = {
            MODE = state
        }

        C4:SendToProxy(5001, "HVAC_MODE_CHANGED", tParams, "NOTIFY")
    end

    if attributes["temperature"] ~= nil and attributes["temperature"] ~= "null" then
        local tempValue = tonumber(attributes["temperature"])

        if state == nil then
            return
        end

        if state == "heat" then
            local tParams = {
                SETPOINT = tempValue,
                SCALE = SELECTED_SCALE
            }

            C4:SendToProxy(5001, "HEAT_SETPOINT_CHANGED", tParams, "NOTIFY")

            LOW_TEMP = tempValue
        elseif state == "cool" then
            local tParams = {
                SETPOINT = tempValue,
                SCALE = SELECTED_SCALE
            }

            C4:SendToProxy(5001, "COOL_SETPOINT_CHANGED", tParams, "NOTIFY")

            HIGH_TEMP = tempValue
        end
    end

    if attributes["target_temp_high"] ~= nil and attributes["target_temp_high"] ~= "null" then
        local tempValue = tonumber(attributes["target_temp_high"])
        local otherValue = tonumber(attributes["target_temp_low"])

        local tParams = {
            SETPOINT = tempValue,
            SCALE = SELECTED_SCALE
        }

        C4:SendToProxy(5001, "COOL_SETPOINT_CHANGED", tParams, "NOTIFY")

        HIGH_TEMP = tempValue
        LOW_TEMP = otherValue
    end

    if attributes["target_temp_low"] ~= nil and attributes["target_temp_low"] ~= "null" then
        local tempValue = tonumber(attributes["target_temp_low"])
        local otherValue = tonumber(attributes["target_temp_high"])

        local tParams = {
            SETPOINT = tempValue,
            SCALE = SELECTED_SCALE
        }

        C4:SendToProxy(5001, "HEAT_SETPOINT_CHANGED", tParams, "NOTIFY")

        LOW_TEMP = tempValue
        HIGH_TEMP = otherValue
    end
end

function SetCurrentTemperatureScale(scaleStr)
    SELECTED_SCALE = scaleStr
    C4:PersistSetValue("CurrentTemperatureScale", SELECTED_SCALE)
    NotifyCurrentTemperatureScale()
end

function NotifyCurrentTemperatureScale()
    C4:SendToProxy(5001, "SCALE_CHANGED", { SCALE = SELECTED_SCALE }, "NOTIFY")
end

function CheckInTimer(timer, skips)
    print("timer expired! refreshing state")
    local tParams = {
		entity = EntityID
	}
	
	C4:SendToProxy(999, "HA_GET_STATE", tParams)
end

