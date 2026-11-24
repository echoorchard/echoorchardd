enum TapQuality { perfect, good, miss }

extension TapQualityX on TapQuality {
  bool get isHarvest => this == TapQuality.perfect || this == TapQuality.good;
}
