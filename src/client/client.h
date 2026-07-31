/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#pragma once
#include "declarations.h"
#include "framework/core/graphicalapplication.h"
#include "framework/core/timer.h"
#include "framework/util/color.h"

class Client : public ApplicationDrawEvents
{
public:
    Client();

    void init(std::vector<std::string>& args);
    void terminate();
    static void registerLuaFunctions();

    void preLoad() override;
    void draw(DrawPoolType type) override;

    bool canDraw(DrawPoolType type) const override;
    bool isLoadingAsyncTexture() override;
    bool isUsingProtobuf() override;

    void onLoadingAsyncTextureChanged(bool loadingAsync) override;
    void doMapScreenshot(std::string fileName) override;

    UIMapPtr getMapWidget() { return m_mapWidget; }

    float getEffectAlpha() const { return getEffectAlpha(Otc::ME_SOURCE_OWN); }
    void setEffectAlpha(const float v) { m_effectAlphas[Otc::ME_SOURCE_OWN] = v; }

    void setOwnSpellEffectAlpha(const float v) { m_effectAlphas[Otc::ME_SOURCE_OWN] = v; }
    float getOwnSpellEffectAlpha() const { return m_effectAlphas[Otc::ME_SOURCE_OWN]; }

    void setOtherPlayerSpellEffectAlpha(const float v) { m_effectAlphas[Otc::ME_SOURCE_OTHER_PLAYER] = v; }
    float getOtherPlayerSpellEffectAlpha() const { return m_effectAlphas[Otc::ME_SOURCE_OTHER_PLAYER]; }

    void setCreatureSpellEffectAlpha(const float v) { m_effectAlphas[Otc::ME_SOURCE_MONSTER] = v; }
    float getCreatureSpellEffectAlpha() const { return m_effectAlphas[Otc::ME_SOURCE_MONSTER]; }

    void setBossAreaCreatureEffectAlpha(const float v) { m_effectAlphas[Otc::ME_SOURCE_BOSS] = v; }
    float getBossAreaCreatureEffectAlpha() const { return m_effectAlphas[Otc::ME_SOURCE_BOSS]; }

    // Helper to get by source directly
    float getEffectAlpha(uint8_t source) const {
        if (source >= m_effectAlphas.size()) return 1.0f;
        return m_effectAlphas[source];
    }

    float getMissileAlpha() const { return m_missileAlpha; }
    void setMissileAlpha(const float v) { m_missileAlpha = v; }

    // Set by the authoritative Master Sorcerer spell-visual opcode. The tint
    // is deliberately scoped to own spell effects by the effect/missile draw
    // paths; other creature sources never consult it.
    void setMasterSorcererSpellVisual(uint32_t sequence, uint16_t spellId, const std::string& element, bool converted);
    void clearMasterSorcererSpellVisual();
    Color getOwnSpellEffectTint();
    int getOwnSpellEffectPalette();
    uint16_t getOwnSpellEffectSpellId() const { return m_masterSorcererVisualSpellId; }

private:
    UIMapPtr m_mapWidget;
    std::array<float, Otc::ME_SOURCE_LAST + 1> m_effectAlphas{};
    float m_missileAlpha{ 1.f };
    Timer m_masterSorcererVisualTimer;
    uint32_t m_masterSorcererVisualSequence{ 0 };
    uint16_t m_masterSorcererVisualSpellId{ 0 };
    int m_masterSorcererVisualPalette{ 0 };
    Color m_masterSorcererVisualTint{ Color::white };
};

extern Client g_client;
