import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

Color greenColor = const Color.fromRGBO(20, 153, 84, 1);
Color redColor = const Color.fromRGBO(228, 49, 43, 1);
Color blackColor = const Color.fromRGBO(0, 0, 0, 1);

final Widget TahrirSlogan = Padding(
  padding: const EdgeInsets.all(10.0),
  child: Column(
    children: [
      Text(
        "لأجل حرية التعبير",
        style: GoogleFonts.notoSansArabic(
          textStyle: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Text(
        "لأجل حرية السوشيال ميديا",
        style: GoogleFonts.notoSansArabic(
          textStyle: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  ),
);

final ButtonStyle TextButtonStyle = ButtonStyle(
  foregroundColor: MaterialStatePropertyAll(greenColor),
  overlayColor: MaterialStateProperty.all(
      greenColor.withOpacity(0.1)), // This changes the hover color
);

final ButtonStyle BlackTextButton = ButtonStyle(
  foregroundColor: MaterialStatePropertyAll(blackColor),
  overlayColor: MaterialStateProperty.all(
      greenColor.withOpacity(0.1)), // This changes the hover color
);

final ButtonStyle FilledButtonStyle = ButtonStyle(
  backgroundColor: MaterialStatePropertyAll(blackColor),
  overlayColor: MaterialStateProperty.all(
      blackColor.withOpacity(0.1)), // This changes the hover color
);

TextStyle defaultText = GoogleFonts.notoSansArabic(
    textStyle:
        const TextStyle(fontWeight: FontWeight.w700, color: Colors.black));

TextStyle topicText = GoogleFonts.notoSansArabic(
    textStyle: TextStyle(
  color: greenColor,
  fontWeight: FontWeight.w700,
));

Widget logo = Column(
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SvgPicture.asset("assets/logo2.svg", width: 200),
      ],
    ),
    Text(
      textScaler: const TextScaler.linear(1.75),
      "قلم",
      style: GoogleFonts.notoSansArabic(
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  ],
);

ThemeData appTheme = ThemeData(
  primaryColor: Colors.white,
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: Colors.transparent,
  ),
  scaffoldBackgroundColor: Colors.grey.shade200,
  cardTheme: const CardTheme(elevation: 1, color: Colors.white),
  appBarTheme: const AppBarTheme(
    elevation: 5,
    color: Colors.white,
    surfaceTintColor: Colors.white,
    foregroundColor: Colors.black,
  ),
  chipTheme: const ChipThemeData(
    shape: StadiumBorder(side: BorderSide.none),
  ),
  radioTheme: RadioThemeData(fillColor: MaterialStatePropertyAll(blackColor)),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black),
    bodyMedium: TextStyle(color: Colors.black),
    displayLarge: TextStyle(color: Colors.black),
    displayMedium: TextStyle(color: Colors.black),
    displaySmall: TextStyle(color: Colors.black),
    headlineLarge: TextStyle(color: Colors.black),
    headlineMedium: TextStyle(color: Colors.black),
    headlineSmall: TextStyle(color: Colors.black),
    titleLarge: TextStyle(color: Colors.black),
    titleMedium: TextStyle(color: Colors.black),
    titleSmall: TextStyle(color: Colors.black),
    bodySmall: TextStyle(color: Colors.black),
    labelLarge: TextStyle(color: Colors.black),
    labelMedium: TextStyle(color: Colors.black),
    labelSmall: TextStyle(color: Colors.black),
  ),
  useMaterial3: true,
  expansionTileTheme: ExpansionTileThemeData(
    iconColor: greenColor,
    collapsedIconColor: blackColor,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(5.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.black),
      borderRadius: BorderRadius.circular(5.0),
    ),
  ),
  cardColor: Colors.white,
  snackBarTheme: SnackBarThemeData(
    showCloseIcon: true,
  ),
  textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.black),
);

Widget horizontalStripes = Row(
  children: [
    Container(width: 10, height: 100, color: blackColor),
    const VerticalDivider(width: 2),
    Container(width: 10, height: 100, color: redColor),
    const VerticalDivider(width: 2),
    Container(width: 10, height: 100, color: greenColor),
  ],
);

Widget shimmer = Shimmer.fromColors(
  baseColor: Colors.grey[500]!,
  highlightColor: Colors.grey[100]!,
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Padding(
        padding: const EdgeInsets.all(50.0),
        child: SvgPicture.asset("assets/logo2.svg", height: 300),
      ),
    ],
  ),
);

Widget coloredLogo = RichText(
  text: TextSpan(
    style: defaultText,
    children: <InlineSpan>[
      TextSpan(text: 'ق', style: TextStyle(color: blackColor, fontSize: 24)),
      TextSpan(text: 'ل', style: TextStyle(color: redColor, fontSize: 24)),
      TextSpan(text: 'م', style: TextStyle(color: greenColor, fontSize: 24)),
    ],
  ),
);

Widget themedCard(child) {
  return Card(
    child: child,
    elevation: 5,
    color: Colors.white,
    surfaceTintColor: Colors.white,
  );
}

Widget pagePadding(child) {
  return Padding(
    padding: EdgeInsets.all(10),
    child: child,
  );
}

Widget circularImage(img) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: CircleAvatar(
      backgroundColor: Colors.grey.shade200,
      radius: 100,
      backgroundImage: img,
    ),
  );
}

void showImage(context, image) {
  showDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return InteractiveViewer(
        child: Image(image: image),
      );
    },
  );
}

Widget titleText(text) {
  return Text(text, style: defaultText);
}

Widget floatingInput(child) {
  return themedCard(
    SingleChildScrollView(
      child: SafeArea(
        bottom: true,
        child: Container(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: child,
          ),
        ),
      ),
    ),
  );
}

InputDecoration textfieldDecoration(String hintText) {
  return InputDecoration(
    label: Text(hintText),
    labelStyle: TextStyle(
      color: Colors.black, // Set your desired color
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30), // Circular/Oval border
    ),
  );
}

bool isArabic(String text) {
  final arabicRegex = RegExp(r'[\u0600-\u06FF]');
  return arabicRegex.hasMatch(text);
}
