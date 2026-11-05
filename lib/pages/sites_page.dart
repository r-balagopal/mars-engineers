import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/site.dart';
import 'site_detail_page.dart';

class SitesPage extends StatefulWidget {
  const SitesPage({super.key});

  @override
  State<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends State<SitesPage> {
  final nameController = TextEditingController();

  String workType = 'Erection';
  String status = 'Active';
  List<Site> sites = [];

  @override
  void initState() {
    super.initState();
    loadSites();
  }

  Future<void> loadSites() async {
    final data = await DatabaseHelper.instance.getSites();

    setState(() {
      sites = data.map((e) => Site.fromMap(e)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
      ),

      body: ListView.builder(
        itemCount: sites.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(sites[index].name),
            subtitle: Text(
              '${sites[index].workType} • ${sites[index].status}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SiteDetailPage(
                    site: sites[index],
                  ),
                ),
              );
            },

            onLongPress: () {
              nameController.text = sites[index].name;
              workType = sites[index].workType;
              status = sites[index].status;

              showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setDialogState) {
                      return AlertDialog(
                        title: const Text('Edit Project'),

                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Project Name',
                              ),
                            ),

                            const SizedBox(height: 15),

                            DropdownButton<String>(
                              value: workType,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Erection',
                                  child: Text('Erection'),
                                ),
                                DropdownMenuItem(
                                  value: 'Dismantling',
                                  child: Text('Dismantling'),
                                ),
                                DropdownMenuItem(
                                  value: 'Operation & Maintenance',
                                  child: Text('Operation & Maintenance'),
                                ),
                                DropdownMenuItem(
                                  value: 'General Labour Supply',
                                  child: Text('General Labour Supply'),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  workType = value!;
                                });
                              },
                            ),

                            const SizedBox(height: 15),

                            DropdownButton<String>(
                              value: status,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Active',
                                  child: Text('Active'),
                                ),
                                DropdownMenuItem(
                                  value: 'Closed',
                                  child: Text('Closed'),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  status = value!;
                                });
                              },
                            ),
                          ],
                        ),

                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel'),
                          ),

                          ElevatedButton(
                            onPressed: () async {
                              await DatabaseHelper.instance.updateSite(
                                sites[index].id!,
                                nameController.text,
                                workType,
                                status,
                              );

                              await loadSites();

                              Navigator.pop(context);
                            },
                            child: const Text('Save'),
                          ),

                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete Project'),
                                  content: Text(
                                    'Are you sure you want to delete "${sites[index].name}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Cancel'),
                                    ),

                                    ElevatedButton(
                                      onPressed: () async {
                                        print("Deleting site id = ${sites[index].id}");

                                        await DatabaseHelper.instance.deleteSite(
                                          sites[index].id!,
                                        );

                                        await loadSites();

                                        Navigator.pop(context); // closes confirmation dialog
                                        Navigator.pop(context); // closes edit dialog
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),

        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    title: const Text('Add Project'),

                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Project Name',
                          ),
                        ),

                        const SizedBox(height: 15),

                        DropdownButton<String>(
                          value: workType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'Erection',
                              child: Text('Erection'),
                            ),
                            DropdownMenuItem(
                              value: 'Dismantling',
                              child: Text('Dismantling'),
                            ),
                            DropdownMenuItem(
                              value: 'Operation & Maintenance',
                              child: Text('Operation & Maintenance'),
                            ),
                            DropdownMenuItem(
                              value: 'General Labour Supply',
                              child: Text('General Labour Supply'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              workType = value!;
                            });
                          },
                        ),

                        const SizedBox(height: 15),

                        DropdownButton<String>(
                          value: status,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'Active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'Closed',
                              child: Text('Closed'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              status = value!;
                            });
                          },
                        ),
                      ],
                    ),

                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),

                      ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.isNotEmpty) {
                            await DatabaseHelper.instance.insertSite(
                              nameController.text,
                              workType,
                              status,
                            );

                            loadSites();

                            nameController.clear();
                            workType = 'Erection';
                            status = 'Active';

                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}