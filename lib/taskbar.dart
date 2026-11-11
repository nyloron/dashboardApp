import 'package:flutter/material.dart';

class Taskbar extends StatefulWidget{
  const Taskbar({super.key});

  @override
  State<Taskbar> createState() => _Taskbar();
}

class _Taskbar extends State<Taskbar>{

  @override
  Widget build(BuildContext context){

    return Container(
      color: Colors.redAccent,
      //height: 55,
      //landscape Mode = max 8 Elements & portrait Mode = max 5 Elements of size 55 
      width: (MediaQuery.of(context).orientation == Orientation.landscape) ? 440 : 275,
      child: TaskbarContent()
    );
  }
}

class TaskbarContent extends StatefulWidget{
  const TaskbarContent({super.key});
  @override
  State<TaskbarContent> createState() => _TaskbarContent();
}
class _TaskbarContent extends State<TaskbarContent>{
  Widget musicPlayerBar(){
    return Text('missing element');
  }

  Widget elementBuilder(int elemtNum){
    //Implement logic for fullscreen App
    IconData fullscreenIcon = (MediaQuery.of(context).orientation == Orientation.landscape) ? Icons.fullscreen_exit : Icons.fullscreen;
    OverflowBar elemetBar = (elemtNum == 5) ? OverflowBar(children: [Text('data')],) : OverflowBar(); 

    return Row(
      children: [
        elemetBar,
        const Spacer(),
        IconButton(onPressed: (){},
        icon: Icon(fullscreenIcon)
        ),
        IconButton(
          onPressed: (){},//ToDo expand/build to App view
          icon: Icon(Icons.window)
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final int elemtNum = (MediaQuery.of(context).orientation == Orientation.landscape) ? 8 : 5;

    //ToDo: Implement logic for deciding between music player or apps to be displayed in the Taskbar
    // ignore: dead_code
    if(false){
      return musicPlayerBar();
    } else{
      return elementBuilder(elemtNum);
    }
  }


}