import 'package:flutter/material.dart';

class AppColors {
  // ========== NEUTROS ==========
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color graphite = Color(0xFF2F2F2F);
  static const Color slateGrey = Color(0xFF6E7E8A);

  // ========== VERDES ==========
  static const Color darkTeal = Color(0xFF225057);
  static const Color deepGreen = Color(0xFF295D54);
  static const Color forestGreen = Color(0xFF2E7D32);
  static const Color slateGreen = Color(0xFF4A6B65);
  static const Color pineGreen = Color(0xFF5D8B6F);
  static const Color seaGreen = Color(0xFF638E67);
  static const Color mintGreen = Color(0xFF86AF86);
  static const Color sageGreen = Color(0xFF9DC183);
  static const Color paleGreen = Color(0xFFA9C1AA);

  // ========== AZULES ==========
  static const Color blueDark = Color(0xFF021F2F);
  static const Color navyBlue = Color(0xFF023858);
  static const Color blueNormal = Color(0xFF064C73);
  static const Color steelBlue = Color(0xFF3A6B8C);
  static const Color blueLight = Color(0xFF369DD6);
  static const Color skyBlue = Color(0xFF54A0CA);
  static const Color aquaBlue = Color(0xFF0FCAB4);

  // ========== CAFÉS/TERROSOS ==========
  static const Color brownDark3 = Color(0xFF3C2D24);
  static const Color brownDark2 = Color(0xFF504136);
  static const Color brownDark1 = Color(0xFF645548);
  static const Color brownMedium = Color(0xFF78695A);
  static const Color brownLight1 = Color(0xFF8C7D6E);
  static const Color brownLight2 = Color(0xFFA09182);
  static const Color brownLight3 = Color(0xFFB4A596);
  static const Color sand = Color(0xFFD2C1B2);

  // ========== ADVERTENCIAS ==========
  static const Color warning = Color(0xFFFF6B6B);
  static const Color warningDark = Color(0xFFFF0000);
  static const Color caution = Color(0xFFFFD166);

  // ========== MODO CLARO ==========
  static const Color backgroundLightPrimary = deepGreen;
  static const Color backgroundLightSecondary = paleGreen;
  static const Gradient backgroundLightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      backgroundLightPrimary,
      backgroundLightSecondary,
    ],
  );
  static const Color backgroundNavBarsLigth = darkTeal;
  static const Color selectedItemLightBottomNavBar = skyBlue;
  static const Color unselectedItemLightBottomNavBar = white;

  // ========== BOTONES ==========
  static const Color buttonBlue1 = blueNormal;
  static const Color buttonBlue2 = steelBlue;
  static const Color buttonBlue3 = blueLight;
  static const Color buttonGreen1 = forestGreen;
  static const Color buttonGreen2 = mintGreen;
  static const Color buttonGreen3 = pineGreen;
  static const Color buttonBrown1 = brownDark1;
  static const Color buttonBrown2 = brownMedium;
  static const Color buttonBrown3 = brownLight1;

  // ========== TEXTOS ==========
  static const Color textBlack = black;
  static const Color textWhite = white;
  static const Color textGraphite = graphite;
  static const Color textSlateGrey = slateGrey;
  static const Color textBlueNormal = blueNormal;
  static const Color textAquaBlue = aquaBlue;
  static const Color textSand = sand;
  static const Color textPaleGreen = paleGreen;

  static const Color backgroundCard = slateGreen;

}