import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

List<String> columnNames = [];
List<List<String>> values = [];

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _isLoading = false;

  void updateData() {
    setState(() {});
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        fetchAndSetData();
      },
    );

    super.initState();
  }

  Future<void> fetchAndSetData() async {
    setState(
      () {
        _isLoading = true;
      },
    );
    var loadedColumns = [];
    var loadedTasksString = [];

    //user clears the data
    await Firestore.instance
        .collection('columns')
        .orderBy('columnIndex')
        .getDocuments()
        .then(
      (value) {
        for (int i = 0; i < value.documents.length; i++) {
          setState(
            () {
              loadedColumns.add(value.documents[i]['columnName']);
              loadedTasksString.add(value.documents[i]['columnTask']);
            },
          );
        }
      },
    );

    for (int i = 0; i < loadedColumns.length; i++) {
      columnNames.add(loadedColumns[i]);
      List<String> tempData = stringToList(loadedTasksString[i]);
      values.add(tempData);
      updateData();
    }

    setState(
      () {
        _isLoading = false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : columnNames.length == 0
              ? Center(
                  child: Text("No Tasks Available!"),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) => Container(
                    width: 200,
                    height: double.infinity,
                    child: ColumnWidget(columnNames[index], index, updateData),
                  ),
                  itemCount: columnNames.length,
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          String columnName = await _stringInputDialog(
              context, 'Column Name: ', 'eg. Office Work/Grocery List');
          if (columnName.length == 0) {
            //Scaffold.of(context).showSnackBar(SnackBar(content: Text("Please provide Column Name"),));
          } else {
            setState(
              () {
                columnNames.add(columnName);
                values.add([]);
              },
            );
            await Firestore.instance.collection('columns').add(
              {
                'columnName': columnName,
                'columnIndex': columnNames.indexOf(columnName),
                'columnTask': '[]'
              },
            );
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

Future<void> updateDataInFireBase(String cName, List<String> taskList) async {
  //var ref=Firestore.instance.collection('columns').getDocuments();
  await Firestore.instance
      .collection('columns')
      .where("columnName", isEqualTo: cName)
      .getDocuments()
      .then(
    (value) {
      var ref = value.documents[0].reference;
      ref.updateData(
        {'columnTask': taskList.toString()},
      );
    },
  );
}

List<String> stringToList(String x) {
  String y = x.substring(1, x.length - 1);

  List<String> result = y.split(',');
  for (int i = 0; i < result.length; i++) {
    result[i] = result[i].trim();
  }
  return result;
}

Future<String> _stringInputDialog(
    BuildContext context, String name, String hint) async {
  String value1 = '';
  return showDialog<String>(
    context: context,
    // barrierDismissible: true, // dialog is dismissible with a tap on the barrier
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(name),
        content: new Row(
          children: <Widget>[
            new Expanded(
              child: new TextField(
                autofocus: true,
                decoration: InputDecoration(hintText: hint),
                onChanged: (value) {
                  value1 = value;
                },
              ),
            ),
          ],
        ),
        actions: <Widget>[
          FlatButton(
            child: Text('Add'),
            onPressed: () {
              Navigator.of(context).pop(value1);
            },
          ),
        ],
      );
    },
  );
}

class ColumnWidget extends StatefulWidget {
  final String cName;
  final int cIndex;
  final Function updateUI;

  ColumnWidget(this.cName, this.cIndex, this.updateUI);
  @override
  _ColumnWidgetState createState() => _ColumnWidgetState();
}

class _ColumnWidgetState extends State<ColumnWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450,
      child: Container(
        margin: EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(),
          borderRadius: BorderRadius.all(
            Radius.circular(5.0),
          ),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.cName,
                        style: TextStyle(color: Colors.grey[700], fontSize: 20),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () async {
                      final String obtainedValue = await _stringInputDialog(
                          context, 'Task Name: ', 'eg. Read a book');
                      setState(
                        () {
                          if (obtainedValue.length == 0) {
                            //Scaffold.of(context).showSnackBar(SnackBar(content: Text('Please Provide Task Name'),));
                          } else {
                            values[widget.cIndex].add(obtainedValue);
                          }
                        },
                      );

                      updateDataInFireBase(widget.cName, values[widget.cIndex]);
                    },
                  ),
                ],
              ),
            ),
            values[widget.cIndex].length == 0
                ? Expanded(
                    child: DragTarget(
                      builder:
                          (context, List<String> candidateData, rejectedData) {
                        return Center(child: Text("Add your task here"));
                      },
                      onWillAccept: (data) => true,
                      onAccept: (data) {
                        setState(
                          () {
                            var index;
                            for (int i = 0; i < values.length; i++) {
                              if (values[i].contains(data)) {
                                values[i].remove(data);
                                index = i;
                              }
                            }
                            values[widget.cIndex].add(data);
                            // print("Data added $data");

                            updateDataInFireBase(
                                widget.cName, values[widget.cIndex]);
                            updateDataInFireBase(
                                columnNames[index], values[index]);
                            // print(values);
                            widget.updateUI();
                          },
                        );
                      },
                    ),
                  )
                : Expanded(
                    child: DragTarget(
                      builder:
                          (context, List<String> candidateData, rejectedData) {
                        return ListView.builder(
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: DragTarget(
                              builder: (context, List<String> candidateData,
                                  rejectedData) {
                                return Draggable(
                                  data: values[widget.cIndex][index],
                                  child: Container(
                                    color: Colors.blue,
                                    child: Text(
                                      values[widget.cIndex][index],
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 22.0),
                                    ),
                                  ),
                                  feedback: Container(
                                    width: 200,
                                    height: 20,
                                    color: Colors.red[300],
                                    child: Text(
                                      values[widget.cIndex][index],
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 22.0),
                                    ),
                                  ),
                                );
                              },
                              onWillAccept: (data) {
                                return true;
                              },
                              onAccept: (data) {
                                setState(
                                  () {
                                    if (values[widget.cIndex].contains(data)) {
                                      var cPlaceData =
                                          values[widget.cIndex][index];
                                      var cPlaceDataIndex =
                                          values[widget.cIndex].indexOf(data);
                                      values[widget.cIndex][cPlaceDataIndex] =
                                          cPlaceData;
                                      //change the current data
                                      values[widget.cIndex][index] = data;

                                      updateDataInFireBase(
                                          widget.cName, values[widget.cIndex]);
                                    } else {
                                      var index;
                                      for (int i = 0; i < values.length; i++) {
                                        if (values[i].contains(data)) {
                                          values[i].remove(data);
                                          index = i;
                                        }
                                      }
                                      widget.updateUI();
                                      values[widget.cIndex].insert(index, data);
                                      // print(values);
                                      updateDataInFireBase(
                                          widget.cName, values[widget.cIndex]);
                                      updateDataInFireBase(
                                          columnNames[index], values[index]);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          itemCount: values[widget.cIndex].length,
                        );
                      },
                      onAccept: (data) {
                        var index;
                        for (int i = 0; i < values.length; i++) {
                          if (values[i].contains(data)) {
                            index = i;
                            values[i].remove(data);
                          }
                        }
                        widget.updateUI();
                        values[widget.cIndex].add(data);
                        // print(values);
                        updateDataInFireBase(
                            widget.cName, values[widget.cIndex]);
                        updateDataInFireBase(columnNames[index], values[index]);
                      },
                      onWillAccept: (data) {
                        return true;
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
