function RFP.SET_MODE_HVAC(idBinding, strCommand, tParams)
	local mode = tParams["MODE"]
	local hvacMode = ""
	if mode == "Off" then
		hvacMode = "off"
	elseif mode == "Heat" then
		hvacMode = "heat"
	elseif mode == "Cool" then
		hvacMode = "cool"
	elseif mode == "Auto" then
		hvacMode = "heat_cool"
	end

	local hvacModeServiceCall = {
		domain = "climate",
		service = "set_hvac_mode",

		service_data = {
			hvac_mode = hvacMode
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

function RFP.SET_MODE_FAN(idBinding, strCommand, tParams)
	local mode = tParams["MODE"]
	local fanMode = ""
	if mode == "Auto" then
		fanMode = "Auto low"
	elseif mode == "On" then
		fanMode = "Low"
	elseif mode == "Circulate" then
		fanMode = "Circulation"
	end

	local hvacModeServiceCall = {
		domain = "climate",
		service = "set_fan_mode",

		service_data = {
			fan_mode = fanMode
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
	local fTemperature = tParams["FAHRENHEIT"]
	local temperatureServiceCall = {}

	if fTemperature <= 0 then
		return
	end

	if MODE == "Auto" then
		temperatureServiceCall = {
			domain = "climate",
			service = "set_temperature",
	
			service_data = {
				target_temp_low = tostring(fTemperature),
				target_temp_high = HIGH_TEMP
			},
	
			target = {
				entity_id = EntityID
			}
		}
	elseif MODE == "Heat" then
		temperatureServiceCall = {
			domain = "climate",
			service = "set_temperature",
	
			service_data = {
				temperature = tostring(fTemperature)
			},
	
			target = {
				entity_id = EntityID
			}
		}
	end

	tParams = {
		JSON = JSON:encode(temperatureServiceCall)
	}

	C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_SETPOINT_COOL(idBinding, strCommand, tParams)
	local fTemperature = tParams["FAHRENHEIT"]
	local temperatureServiceCall = {}

	if fTemperature <= 0 then
		return
	end

	if MODE == "Auto" then
		temperatureServiceCall = {
			domain = "climate",
			service = "set_temperature",
	
			service_data = {
				target_temp_high = fTemperature,
				target_temp_low = LOW_TEMP
			},
	
			target = {
				entity_id = EntityID
			}
		}
	elseif MODE == "Cool" then
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

    if not Connected then
        Connected = true

        local tParams =
        {
            CONNECTED = "true"
        }
        C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
    end

    local attributes = data["attributes"]
    local state = data["state"]

    if attributes == nil then
        local tParams =
        {
            CONNECTED = "false"
        }
        C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
        return
    end

    if attributes["current_temperature"] ~= nil then
        local temperature = tonumber(attributes["current_temperature"])

        local tParams = {
            TEMPERATURE = temperature,
            SCALE = "F"
        }

        C4:SendToProxy(5001, "TEMPERATURE_CHANGED", tParams, "NOTIFY")
    end

    if attributes["current_humidity"] ~= nil then
        local tParams = {
            HUMIDITY = tonumber(attributes["current_humidity"])
        }

        C4:SendToProxy(5001, "HUMIDITY_CHANGED", tParams, "NOTIFY")
    end

    if attributes["fan_mode"] ~= nil then
        local value = attributes["fan_mode"]
        local operatingModeString = ""

        if value == "Auto low" then
            operatingModeString = "Auto"
        elseif value == "Low" then
            operatingModeString = "On"
        elseif value == "Circulation" then
            operatingModeString = "Circulate"
        end

        local tParams = {
            MODE = operatingModeString
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
    end

    if attributes["hvac_action"] ~= nil then
        local hvacActionString = ""
        local value = attributes["hvac_action"]

        if value == "cooling" then
            hvacActionString = "Cooling"
        elseif value == "heating" then
            hvacActionString = "Heating"
        elseif value == "off" then
            hvacActionString = "Off"
        end

        local tParams = {
            STATE = hvacActionString
        }

        C4:SendToProxy(5001, "HVAC_STATE_CHANGED", tParams, "NOTIFY")
    end

    if state ~= nil then
        local operatingModeString = ""

        if state == "off" then
            operatingModeString = "Off"
        elseif state == "heat" then
            operatingModeString = "Heat"
        elseif state == "cool" then
            operatingModeString = "Cool"
        elseif state == "heat_cool" then
            operatingModeString = "Auto"
        end

        MODE = operatingModeString

        local tParams = {
            MODE = operatingModeString
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
                SCALE = "F"
            }

            C4:SendToProxy(5001, "HEAT_SETPOINT_CHANGED", tParams, "NOTIFY")

            LOW_TEMP = tempValue
        elseif state == "cool" then
            local tParams = {
                SETPOINT = tempValue,
                SCALE = "F"
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
            SCALE = "F"
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
            SCALE = "F"
        }

        C4:SendToProxy(5001, "HEAT_SETPOINT_CHANGED", tParams, "NOTIFY")

        LOW_TEMP = tempValue
        HIGH_TEMP = otherValue
    end
end
