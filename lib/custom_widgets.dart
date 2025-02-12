
import 'package:bewerbsapp/data/global_data.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

Widget actionButton(BuildContext context, double width, Color color, Color iconColor, Icon icon, double iconsize, Function() onTap){
  return IconButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      minimumSize: Size(width, width),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(150),
      ),

    ),

    icon: icon,
    iconSize: iconsize,
    color: iconColor,
  );
}

class SimpleLineChart extends StatelessWidget {

  final List<FlSpot> dataPoints;
  final List<Map<String, dynamic>> times;

  SimpleLineChart({
    required this.dataPoints, required this.times,
  });

  @override
  Widget build(BuildContext context) {

    if (dataPoints.isEmpty) {
      dataPoints.add(FlSpot(0, 0));  // Füge einen Punkt hinzu, um das Diagramm darzustellen
    }
    return  ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      child: LineChart(
        LineChartData(
          minY: -1,

            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Color(0x77121212), // Gitterfarbe grau
                  strokeWidth: 0.5, // Sehr feine Gitterlinien
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Color(0x77121212),  // Gitterfarbe grau
                  strokeWidth: 0.5, // Sehr feine Gitterlinien
                );
              },
            ),
          titlesData: FlTitlesData(
            show: false,


          ),
          borderData: FlBorderData(show: false), // Ränder des Diagramms entfernen
          lineBarsData: [
            LineChartBarData(

              spots: dataPoints,
              isCurved: true, // Linie soll gebogen sein
              curveSmoothness: 0.2, // Biegung der Linie anpassen
              color: basicAppRed, // Linienfarbe
              dotData: FlDotData(show: false), // Punkte entfernen
              belowBarData: BarAreaData(show: false), // Bereich unter der Linie entfernen
            ),
          ],
          backgroundColor: basicContainerColor,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((LineBarSpot spot) {
                  return LineTooltipItem(
                    '${times[spot.x.round()]["runTimeDate"].substring(0, 19)} ${spot.y } sek.', // Text der angezeigt wird
                    TextStyle(color: Colors.white), // Weiße Schrift
                  );
                }).toList();
              },
            ),
          ),
          minX: -1,
          maxX: dataPoints.map((e) => e.x).reduce((a, b) => a > b ? a : b) + 1,

          maxY: dataPoints.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 10,
        ),
      ),
    );
  }
}


void showFloatingSnackbar(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 50.0,
      left: 20.0,
      right: 20.0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text(message, style: TextStyle(color: Colors.white))),
            ],
          ),
        ),
      ),
    ),
  );

  // Füge die Snackbar in den Overlay ein
  overlay.insert(overlayEntry);

  // Entferne sie nach einer bestimmten Zeit (z.B. 2 Sekunden)
  Future.delayed(Duration(seconds: 2), () {
    overlayEntry.remove();
  });
}